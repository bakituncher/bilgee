import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/shared/widgets/logo_loader.dart';

// State model for the user management screen
class UserManagementState {
  final List<Map<String, dynamic>> users;
  final String? nextPageToken;
  final bool isLoading;
  final bool isSearching;
  final String? error;

  UserManagementState({
    this.users = const [],
    this.nextPageToken,
    this.isLoading = false,
    this.isSearching = false,
    this.error,
  });

  UserManagementState copyWith({
    List<Map<String, dynamic>>? users,
    String? nextPageToken,
    bool? isLoading,
    bool? isSearching,
    String? error,
    bool clearNextPageToken = false,
  }) {
    return UserManagementState(
      users: users ?? this.users,
      nextPageToken: clearNextPageToken ? null : nextPageToken ?? this.nextPageToken,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: error ?? this.error,
    );
  }
}

// StateNotifier to manage the state of the user list
class UserManagementNotifier extends StateNotifier<UserManagementState> {
  final Ref _ref;
  Timer? _debounce;

  UserManagementNotifier(this._ref) : super(UserManagementState()) {
    fetchFirstPage();
  }

  Future<void> fetchFirstPage() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final functions = _ref.read(functionsProvider);
      final result = await functions.httpsCallable('admin-getUsers').call();
      final data = result.data as Map<String, dynamic>?;

      final usersList = List.from(data?['users'] ?? []);
      final castedList = usersList.map((user) => Map<String, dynamic>.from(user as Map)).toList();

      state = state.copyWith(
        users: castedList,
        nextPageToken: data?['nextPageToken'] as String?,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.nextPageToken == null) return;

    state = state.copyWith(isLoading: true);
    try {
      final functions = _ref.read(functionsProvider);
      final result = await functions.httpsCallable('admin-getUsers').call({
        'pageToken': state.nextPageToken,
      });
      final data = result.data as Map<String, dynamic>?;

      final usersList = List.from(data?['users'] ?? []);
      final castedList = usersList.map((user) => Map<String, dynamic>.from(user as Map)).toList();

      state = state.copyWith(
        users: [...state.users, ...castedList],
        nextPageToken: data?['nextPageToken'] as String?,
        isLoading: false,
        clearNextPageToken: data?['nextPageToken'] == null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> searchUserByEmail(String email) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (email.trim().isEmpty) {
        state = state.copyWith(isSearching: false);
        fetchFirstPage();
        return;
      }

      state = state.copyWith(isLoading: true, isSearching: true, users: [], error: null);
      try {
        final functions = _ref.read(functionsProvider);
        final result = await functions.httpsCallable('admin-findUserByEmail').call({'email': email.trim()});
        final user = result.data as Map<String, dynamic>?;

        state = state.copyWith(
          users: user != null ? [user] : [],
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    });
  }

  // Helper to update a user in the list locally after claim change
  void updateUserClaim(String uid, bool isAdmin) {
    final updatedUsers = state.users.map((user) {
      if (user['uid'] == uid) {
        return {...user, 'admin': isAdmin};
      }
      return user;
    }).toList();
    state = state.copyWith(users: updatedUsers);
  }
}

final userManagementProvider = StateNotifierProvider<UserManagementNotifier, UserManagementState>((ref) {
  return UserManagementNotifier(ref);
});

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        // Do not fetch next page if searching
        if (ref.read(userManagementProvider).isSearching == false) {
          ref.read(userManagementProvider.notifier).fetchNextPage();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userManagementProvider);
    final notifier = ref.read(userManagementProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Email ile Kullanıcı Ara',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    notifier.searchUserByEmail('');
                  },
                ),
              ),
              onChanged: (value) {
                notifier.searchUserByEmail(value);
              },
            ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Bir hata oluştu: ${state.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: state.users.length + (state.isLoading && !state.isSearching ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == state.users.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                final user = state.users[index];
                final isAdmin = user['admin'] as bool? ?? false;

                return ListTile(
                  title: Text(user['displayName'] ?? 'İsimsiz'),
                  subtitle: Text(user['email'] ?? 'E-posta yok'),
                  trailing: Switch(
                    value: isAdmin,
                    activeColor: AppTheme.successColor,
                    onChanged: (bool value) async {
                      try {
                        final functions = ref.read(functionsProvider);
                        await functions.httpsCallable('admin-setAdminClaim').call({
                          'uid': user['uid'],
                          'makeAdmin': value,
                        });
                        notifier.updateUserClaim(user['uid'], value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${user['displayName']} için admin yetkisi güncellendi.')),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Hata: $e')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
          if (state.isLoading && state.users.isEmpty && state.error == null)
            const Expanded(child: LogoLoader()),
        ],
      ),
    );
  }
}
