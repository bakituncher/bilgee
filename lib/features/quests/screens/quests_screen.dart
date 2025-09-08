// lib/features/quests/screens/quests_screen.dart
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';

// Filtre tipi (top-level enum)
// enum _QuestFilter { all, daily, weekly, monthly }

// ===================== HELPER WIDGETS ÖNE ALINDI =====================
class QuestCard extends StatelessWidget {
  final Quest quest; final Set<String> completedIds; final String? userId; final Map<String,Quest> allQuestsMap; final WidgetRef ref;
  const QuestCard({super.key, required this.quest, required this.completedIds, this.userId, required this.allQuestsMap, required this.ref});
  IconData _getIconForCategory(QuestCategory category){
    switch(category){
      case QuestCategory.study: return Icons.book_rounded;
      case QuestCategory.practice: return Icons.edit_note_rounded;
      case QuestCategory.engagement: return Icons.auto_awesome;
      case QuestCategory.consistency: return Icons.event_repeat_rounded;
      case QuestCategory.test_submission: return Icons.add_chart_rounded;
      case QuestCategory.focus: return Icons.center_focus_strong;
    }
  }
  List<Widget> _buildPriorityBadges(BuildContext context, Quest quest,{bool locked=false,List<String> prereqNames=const []}){
    final chips=<Widget>[];
    if(locked){
      final label=prereqNames.isEmpty?'Önkoşul':'Önkoşul: '+prereqNames.take(2).join(', ');
      chips.add(InkWell(onTap: (){
        final msg = prereqNames.isEmpty? 'Bu görevi açmak için önkoşulları tamamla.' : 'Önkoşul: '+prereqNames.join(', ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }, child: _badge(label,Icons.lock_clock,Colors.deepPurpleAccent)));
    }
    final isHighValue = quest.reward>=90 || quest.tags.contains('high_value');
    if(isHighValue) chips.add(_badge('Öncelik', Icons.flash_on, Colors.amber));
    if(quest.tags.contains('weakness')) chips.add(_badge('Zayıf Nokta', Icons.warning_amber, Colors.redAccent));
    if(quest.tags.contains('adaptive')) chips.add(_badge('Adaptif', Icons.auto_fix_high, Colors.lightBlueAccent));
    if(quest.tags.contains('chain')) chips.add(_badge('Zincir', Icons.link, Colors.tealAccent));
    if(quest.tags.contains('retention')) chips.add(_badge('Geri Dönüş', Icons.refresh, Colors.orangeAccent));
    if(quest.tags.contains('focus')) chips.add(_badge('Odak', Icons.center_focus_strong, Colors.cyanAccent));
    if(quest.tags.contains('plan')) chips.add(_badge('Plan', Icons.schedule, Colors.blueGrey));
    return chips;
  }
  Widget _badge(String text,IconData icon,Color color)=>Chip(label:Text(text),avatar:Icon(icon,size:16,color:AppTheme.primaryColor),backgroundColor:color.withValues(alpha:0.85),labelStyle:const TextStyle(fontSize:11,fontWeight:FontWeight.bold,color:AppTheme.primaryColor),materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,visualDensity:VisualDensity.compact,);
  Widget _buildChainSegments(Quest q){ if(q.chainId==null||q.chainStep==null||q.chainLength==null) return const SizedBox.shrink(); return Padding(padding: const EdgeInsets.only(top:6), child: Row(children: List.generate(q.chainLength!, (i){final active=i<q.chainStep!; return Expanded(child: AnimatedContainer(duration:300.ms, margin: EdgeInsets.symmetric(horizontal:i==1?4:2), height:6, decoration:BoxDecoration(color: active?AppTheme.secondaryColor:AppTheme.lightSurfaceColor.withValues(alpha:0.3), borderRadius: BorderRadius.circular(4)),));}))); }
  @override Widget build(BuildContext context){
    final isCompleted=quest.isCompleted;
    final progress=quest.goalValue>0?((quest.currentProgress/quest.goalValue).clamp(0.0,1.0)):1.0;
    final locked=!isCompleted && quest.prerequisiteIds.isNotEmpty && !quest.prerequisiteIds.every((id)=>completedIds.contains(id));
    return Card(
      margin: const EdgeInsets.only(bottom:16),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: InkWell(
        onTap: (isCompleted||locked)?(){ if(locked){
          final names = quest.prerequisiteIds.map((id)=> allQuestsMap[id]?.title ?? id).toList();
          final msg = names.isEmpty? 'Önce önkoşul görev(ler)ini tamamla' : 'Önkoşul: '+names.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }
        }:(){ if(userId!=null){ref.read(analyticsLoggerProvider).logQuestEvent(userId: userId!, event:'quest_tap', data:{'questId':quest.id,'category':quest.category.name});}
          String target=quest.actionRoute; if(target=='/coach'){ final subjectTag=quest.tags.firstWhere((t)=>t.startsWith('subject:'), orElse:()=>'' ); if(subjectTag.isNotEmpty){ final subj=subjectTag.split(':').sublist(1).join(':'); target=Uri(path:'/coach', queryParameters:{'subject':subj}).toString(); }} context.go(target); },
        child: Stack(children:[
          // Renkli degrade zemin
          Container(
            decoration: BoxDecoration(
              gradient: _gradForCategory(quest.category, isCompleted),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16,16,16,8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  CircleAvatar(backgroundColor: Colors.black.withOpacity(0.15), child: Icon(_getIconForCategory(quest.category), color: Colors.white)), const SizedBox(width:16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                    Text(quest.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height:4),
                    Text(quest.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  ])),
                ]),
                const SizedBox(height:8),
                Wrap(spacing:8, runSpacing:4, children:[
                  ..._buildPriorityBadges(context, quest, locked:locked, prereqNames: quest.prerequisiteIds.map((id)=>allQuestsMap[id]?.title??id).toList()),
                  if(quest.id.startsWith('schedule_')) Chip(label: const Text('Plan'), visualDensity: VisualDensity.compact, backgroundColor: Colors.white.withOpacity(0.18), labelStyle: const TextStyle(fontSize:12, color: Colors.white)),
                  Chip(avatar: const Icon(Icons.star_rounded,color:Colors.amber,size:16), label: Text('+${quest.reward} BP'), visualDensity: VisualDensity.compact, backgroundColor: Colors.white.withOpacity(0.18), labelStyle: const TextStyle(color: Colors.white)),
                ]),
                const SizedBox(height:8),
                if(!isCompleted) Row(children:[
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value:progress,minHeight:8, backgroundColor: Colors.white.withOpacity(0.18), valueColor: AlwaysStoppedAnimation(Colors.white)))),
                  const SizedBox(width:12),
                  Text('${quest.currentProgress} / ${quest.goalValue}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                const SizedBox(height:8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                  if(isCompleted && quest.rewardClaimed) Row(children: const [Text('Fethedildi!', style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold)), SizedBox(width:4), Icon(Icons.check_circle_rounded,color:Colors.white,size:20)]).animate().fadeIn().scale(delay:150.ms, curve: Curves.easeOutBack),
                  if(isCompleted && !quest.rewardClaimed) Expanded(child: ElevatedButton.icon(onPressed: userId==null? null : () async {
                    try {
                      await ref.read(firestoreServiceProvider).claimQuestReward(userId!, quest);
                      ref.invalidate(dailyQuestsProvider);
                      if(context.mounted){
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ödül tahsil edildi! 🎉'),
                          backgroundColor: Colors.green,
                        ));
                      }
                    } catch (e) {
                      if(context.mounted){
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Ödül alma hatası: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    }
                  }, icon: const Icon(Icons.card_giftcard_rounded), label: const Text('Ödülü Al!'))),
                  if(!isCompleted) const Row(children:[Text('Yola Koyul', style: TextStyle(color: Colors.white70)), SizedBox(width:4), Icon(Icons.arrow_forward, color: Colors.white70, size:16)])
                ]),
                const SizedBox(height:4),
                _QuestHintLine(quest: quest),
                _buildChainSegments(quest),
              ]),
            ),
          ),
          if(locked) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.45), child: const Center(child: Icon(Icons.lock,color:Colors.white70,size:40))))
        ]),
      ),
    );
  }

  LinearGradient _gradForCategory(QuestCategory c, bool completed){
    Color a,b;
    switch(c){
      case QuestCategory.practice: a=Colors.deepPurpleAccent; b=Colors.purple; break;
      case QuestCategory.study: a=Colors.indigoAccent; b=Colors.blue; break;
      case QuestCategory.engagement: a=Colors.pinkAccent; b=Colors.orange; break;
      case QuestCategory.consistency: a=Colors.tealAccent; b=Colors.teal; break;
      case QuestCategory.test_submission: a=Colors.amberAccent; b=Colors.deepOrange; break;
      case QuestCategory.focus: a=Colors.cyanAccent; b=Colors.cyan; break;
    }
    if(completed){ a = a.withOpacity(0.25); b = b.withOpacity(0.15);} else { a=a.withOpacity(0.35); b=b.withOpacity(0.2);}
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors:[a,b]);
  }
}
class _IssueBanner extends StatelessWidget { final VoidCallback onClose; const _IssueBanner({required this.onClose}); @override Widget build(BuildContext context){ return Card(color: AppTheme.accentColor.withValues(alpha:0.15), child: Padding(padding: const EdgeInsets.symmetric(horizontal:12,vertical:10), child: Row(children:[const Icon(Icons.cloud_off,color:AppTheme.accentColor), const SizedBox(width:12), const Expanded(child: Text('Görev üretimi bağlantı sorunları nedeniyle önbellekten gösteriliyor.', style: TextStyle(color: AppTheme.secondaryTextColor,fontSize:12))), IconButton(onPressed:onClose, icon: const Icon(Icons.close,size:18,color:AppTheme.secondaryTextColor))] ),)); }}
class _SummaryBar extends ConsumerWidget {
  final List<Quest> quests; final dynamic user; const _SummaryBar({required this.quests, required this.user});
  @override Widget build(BuildContext context, WidgetRef ref){
    final total=quests.where((q)=>q.type==QuestType.daily).length;
    final done=quests.where((q)=>q.type==QuestType.daily && q.isCompleted).length;
    final weeklyTotal=quests.where((q)=>q.type==QuestType.weekly).length;
    final weeklyDone=quests.where((q)=>q.type==QuestType.weekly && q.isCompleted).length;
    final monthlyTotal=quests.where((q)=>q.type==QuestType.monthly).length;
    final monthlyDone=quests.where((q)=>q.type==QuestType.monthly && q.isCompleted).length;
    final focusMinutes=quests.where((q)=>q.category==QuestCategory.focus).fold<int>(0,(s,q)=>s+q.currentProgress);
    final practiceSolved=quests.where((q)=>q.category==QuestCategory.practice).fold<int>(0,(s,q)=>s+q.currentProgress);
    double planRatio=0;
    try{
      final today=DateTime.now();
      final completed=ref.watch(completedTasksForDateProvider(today)).maybeWhen(data:(list)=>list.length, orElse: ()=>0);
      final planTotalRaw=quests.where((q)=>q.id.startsWith('schedule_')).length;
      final planTotal=planTotalRaw==0?1:planTotalRaw;
      planRatio=completed/planTotal;
    }catch(_){ }

    return Container(
      margin: const EdgeInsets.only(bottom:12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors:[Color(0xFF3A7BD5), Color(0xFF00D2FF)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[ Expanded(child:_metric('Günlük', '$done/$total')), Expanded(child:_metric('Haftalık', '$weeklyDone/$weeklyTotal')), Expanded(child:_metric('Aylık', '$monthlyDone/$monthlyTotal')), Expanded(child:_metric('Plan %','${(planRatio*100).round()}%')), Expanded(child:_metric('Odak dk',focusMinutes.toString())), Expanded(child:_metric('Soru',practiceSolved.toString())), ]), const SizedBox(height:8), LinearProgressIndicator(value: total==0?0.0:done/total, minHeight:6, backgroundColor: Colors.white.withOpacity(0.25), valueColor: const AlwaysStoppedAnimation(Colors.white)), ]),
    );
  }
  Widget _metric(String l,String v)=>Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(l, style: const TextStyle(fontSize:11,color:Colors.white70)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), ]);
}
class _QuestHintLine extends StatelessWidget { final Quest quest; const _QuestHintLine({required this.quest}); String _hint(){ switch(quest.category){ case QuestCategory.practice: return quest.goalValue<=5?'Mini başla: birkaç soru tetikler.':'${quest.goalValue} soru hedefi. Bilgi Galaksisi ekranından soru çöz.'; case QuestCategory.study: return 'Plan / konu hakimiyeti. İlgili maddeyi haftalık plandan bitir.'; case QuestCategory.engagement: if(quest.actionRoute.contains('pomodoro')) return 'Pomodoro ekranında odak seansı başlat.'; if(quest.actionRoute.contains('stats')) return 'Performans Kalesi ekranını aç.'; return 'İlgili özelliği ziyaret et ve etkileşimi tamamla.'; case QuestCategory.consistency: return 'Gün içi düzen. Uygulamayı farklı zamanlarda aç / seri koru.'; case QuestCategory.test_submission: return 'Yeni bir deneme sonucu ekle.'; case QuestCategory.focus: return 'Odak turları biriktir. Seansları tamamla.'; } }
@override Widget build(BuildContext context)=> Text(_hint(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor, fontStyle: FontStyle.italic)); }
class _SectionHeader extends StatelessWidget { final String title; const _SectionHeader({required this.title}); @override Widget build(BuildContext context)=> Padding(padding: const EdgeInsets.only(top:16,bottom:16), child: Row(children:[ const Expanded(child: Divider(color: AppTheme.lightSurfaceColor)), Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Text(title, style: const TextStyle(color: AppTheme.secondaryTextColor,fontWeight: FontWeight.bold))), const Expanded(child: Divider(color: AppTheme.lightSurfaceColor)), ])); }

// ===================== ANA EKRAN =====================
class QuestsScreen extends ConsumerStatefulWidget { const QuestsScreen({super.key}); static const Map<QuestCategory,String> categoryHelp={
  QuestCategory.practice:'Practice: Soru çözme / hız çalışmaları. İlerleme: çözdüğün soru sayısı.',
  QuestCategory.study:'Study: Konu hakimiyeti / plan görevi tamamlamak. İlerleme: tamamlanan konu veya plan maddesi.',
  QuestCategory.engagement:'Engagement: Uygulama içi etkileşim (istatistik inceleme, pomodoro vb.).',
  QuestCategory.consistency:'Consistency: Düzen ve süreklilik (gün içi tekrar ziyaret, seri koruma).',
  QuestCategory.test_submission:'Test: Deneme ekleme ve sonuç raporlama.',
  QuestCategory.focus:'Focus: Odak seansı dakikaları biriktirme / zincir ilerletme.',}; @override ConsumerState<QuestsScreen> createState()=>_QuestsScreenState(); }
class _QuestsScreenState extends ConsumerState<QuestsScreen>{
  late ConfettiController _confettiController; final _loggedViews=<String>{};
  // Yeni: arama ve sıralama
  String _search = '';
  String _sort = 'önerilen'; // önerilen | ödül | ilerleme

  // Liste modu: Aktif / Tamamlanan (tab bazlı)
  final Map<QuestType, String> _modeByType = {
    QuestType.daily: 'aktif',
    QuestType.weekly: 'aktif',
    QuestType.monthly: 'aktif',
  };
  // Kategori filtreleri
  final Set<QuestCategory> _catFilter = {};

  @override void initState(){ super.initState(); _confettiController=ConfettiController(duration: const Duration(seconds:1)); }
  @override void dispose(){ _confettiController.dispose(); super.dispose(); }

  // Toplu ödül tahsil et
  Future<void> _claimAllRewards(WidgetRef ref, String userId, List<Quest> claimables, BuildContext context) async {
    int successCount = 0;
    int errorCount = 0;
    String? lastError;

    for(final q in claimables){
      try {
        await ref.read(firestoreServiceProvider).claimQuestReward(userId, q);
        successCount++;
      } catch(e){
        errorCount++;
        lastError = e.toString();
        print('Ödül alma hatası (${q.title}): $e');
      }
    }

    ref.invalidate(dailyQuestsProvider);

    if(context.mounted){
      if (errorCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tüm ödüller başarıyla alındı! ($successCount ödül) 🎉'),
            backgroundColor: Colors.green,
          )
        );
      } else if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount ödül alındı, $errorCount hatası var. Son hata: $lastError'),
            backgroundColor: Colors.orange,
          )
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hiçbir ödül alınamadı. Hata: $lastError'),
            backgroundColor: Colors.red,
          )
        );
      }
    }
  }

  @override Widget build(BuildContext context){
    final loadAsync=ref.watch(dailyQuestsProvider);
    final allQuests=ref.watch(optimizedDailyQuestsProvider);
    final user=ref.watch(userProfileProvider).value;

    ref.listen<List<Quest>>(optimizedDailyQuestsProvider,(prev,next){ if(prev==null||prev.isEmpty) return; if(next.where((q)=>q.isCompleted).length>prev.where((q)=>q.isCompleted).length){ _confettiController.play(); }});
    final isLoading=loadAsync.isLoading && allQuests.isEmpty;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fetih Kütüğü'),
          actions:[
            IconButton(tooltip:'Ara', icon: const Icon(Icons.search), onPressed: ()=>_openSearchSheet(context)),
            IconButton(tooltip:'Görev Rehberi', icon: const Icon(Icons.help_center_outlined), onPressed: ()=>_showHelp(context)),
            IconButton(tooltip:'Yenile', icon: const Icon(Icons.refresh_rounded), onPressed: user==null?null:() async { await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} ),
          ],
          bottom: const TabBar(isScrollable: false, tabs: [
            Tab(text: 'Günlük'),
            Tab(text: 'Haftalık'),
            Tab(text: 'Aylık'),
          ]),
        ),
        body: Stack(alignment: Alignment.topCenter, children:[
          if(isLoading) const Center(child:CircularProgressIndicator(color: AppTheme.secondaryColor))
          else if(allQuests.isEmpty) _buildEmptyState(context)
          else TabBarView(children: [
            _buildTabContent(context, allQuests, user, QuestType.daily),
            _buildTabContent(context, allQuests, user, QuestType.weekly),
            _buildTabContent(context, allQuests, user, QuestType.monthly),
          ]),
          ConfettiWidget(confettiController:_confettiController, blastDirectionality: BlastDirectionality.explosive, shouldLoop:false, colors: const [AppTheme.secondaryColor, AppTheme.successColor, Colors.white]),
        ]),
      ),
    );
  }

  // Yeni: Tab içeriği (aktif + tamamlanan açılır bölüm + özet)
  Widget _buildTabContent(BuildContext context, List<Quest> all, dynamic user, QuestType type){
    // 1) Veri hazırlığı (tip + arama)
    List<Quest> list = all.where((q)=>q.type==type).toList();
    if(_search.isNotEmpty){ final s=_search.toLowerCase(); list = list.where((q)=> q.title.toLowerCase().contains(s) || q.description.toLowerCase().contains(s)).toList(); }

    // 2) Bölümlere ayır
    final claimables = list.where((q)=> q.isCompleted && !q.rewardClaimed).toList()
      ..sort((a,b){ final at=a.completionDate?.millisecondsSinceEpoch??0; final bt=b.completionDate?.millisecondsSinceEpoch??0; return bt.compareTo(at);});
    List<Quest> active = list.where((q)=> !q.isCompleted).toList();

    // 3) Sıralama (aktifler için)
    active.sort((a,b){
      switch(_sort){
        case 'ödül': return b.reward.compareTo(a.reward);
        case 'ilerleme':
          final ap = a.goalValue==0?0.0:a.currentProgress/a.goalValue;
          final bp = b.goalValue==0?0.0:b.currentProgress/b.goalValue;
          return bp.compareTo(ap);
        case 'önerilen':
        default:
          return b.reward.compareTo(a.reward);
      }
    });

    final completedIds=all.where((q)=>q.isCompleted).map((q)=>q.id).toSet();
    final allMap={for(final q in all) q.id:q};
    final issue=ref.watch(questGenerationIssueProvider);

    return RefreshIndicator(
      onRefresh: () async { if(user!=null){ await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16,16,16,120),
        children: [
          if(type==QuestType.daily) _SummaryBar(quests: all, user: user),
          if(issue) _IssueBanner(onClose: ()=> ref.read(questGenerationIssueProvider.notifier).state=false),

          // Ödül bölümünü öne al
          if(claimables.isNotEmpty)...[
            Row(children:[
              const Expanded(child: _SectionHeader(title:'Ödülünü Al')),
              if(user!=null) TextButton.icon(onPressed: ()=> _claimAllRewards(ref, user.id, claimables, context), icon: const Icon(Icons.card_giftcard_rounded), label: const Text('Tümünü Al')),
            ]),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (c,i){ final q = claimables[i]; return SizedBox(width: 280, child: _SmallQuestCard(quest:q, userId:user?.id, completedIds: completedIds, allQuestsMap: allMap, ref: ref)); },
                separatorBuilder: (_, __)=> const SizedBox(width:12),
                itemCount: claimables.length>12?12:claimables.length,
              ),
            ),
            const SizedBox(height:12),
          ],

          // Devam edenler
          const _SectionHeader(title:'Devam Eden Görevler'),
          if(active.isEmpty)
            _emptySection(context,
              title: type==QuestType.daily? 'Bugün görev yok': type==QuestType.weekly? 'Haftalık görev yok':'Aylık görev yok',
              desc: 'Yenile ile yeni görev oluşturmayı deneyin.',
              onRefresh: () async { if(user!=null){ await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} },
            )
          else ...active.map((q)=> QuestCard(quest:q, completedIds:completedIds, userId:user?.id, allQuestsMap: allMap, ref:ref)),
        ],
      ).animate().fadeIn(duration:400.ms).slideY(begin:0.05),
    );
  }

  // Mod geçişi (Aktif / Tamamlanan)
  Widget _buildModeToggle(QuestType type){
    final mode = _modeByType[type] ?? 'aktif';
    return Padding(
      padding: const EdgeInsets.only(bottom:8),
      child: Row(children: [
        ChoiceChip(label: const Text('Aktif'), selected: mode=='aktif', onSelected: (_){ setState(()=> _modeByType[type] = 'aktif'); }),
        const SizedBox(width:8),
        ChoiceChip(label: const Text('Tamamlanan'), selected: mode=='tamamlanan', onSelected: (_){ setState(()=> _modeByType[type] = 'tamamlanan'); }),
      ]),
    );
  }

  // Kategori filtre çipleri
  Widget _buildCategoryFilters(){
    Widget chip(QuestCategory c, String label){
      final sel = _catFilter.contains(c);
      return FilterChip(label: Text(label), selected: sel, onSelected: (v){ setState((){ if(v) _catFilter.add(c); else _catFilter.remove(c); }); });
    }
    return Padding(
      padding: const EdgeInsets.only(bottom:8),
      child: Wrap(spacing:8, runSpacing:4, children: [
        ActionChip(label: const Text('Hepsi'), onPressed: ()=> setState(()=> _catFilter.clear())),
        chip(QuestCategory.practice, 'Pratik'),
        chip(QuestCategory.study, 'Çalışma'),
        chip(QuestCategory.focus, 'Odak'),
        chip(QuestCategory.consistency, 'Düzen'),
        chip(QuestCategory.engagement, 'Etkileşim'),
        chip(QuestCategory.test_submission, 'Test'),
      ]),
    );
  }

  Widget _buildSortRow(BuildContext context){
    return Padding(
      padding: const EdgeInsets.only(bottom:12),
      child: Row(children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Görev ara...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v)=> setState(()=> _search = v.trim()),
          ),
        ),
        const SizedBox(width:12),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _sort,
            borderRadius: BorderRadius.circular(10),
            items: const [
              DropdownMenuItem(value: 'önerilen', child: Text('Önerilen')),
              DropdownMenuItem(value: 'ödül', child: Text('Ödül')),
              DropdownMenuItem(value: 'ilerleme', child: Text('İlerleme')),
            ],
            onChanged: (v){ if(v!=null) setState(()=> _sort = v); },
          ),
        ),
      ]),
    );
  }

  Widget _emptySection(BuildContext context, {required String title, required String desc, required VoidCallback onRefresh}){
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height:6), Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)), const SizedBox(height:12), Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed:onRefresh, icon: const Icon(Icons.autorenew), label: const Text('Görevleri Getir'))), ])));
  }

  Widget _buildEmptyState(BuildContext context)=> Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[ const Icon(Icons.shield_moon_rounded,size:80,color:AppTheme.secondaryTextColor), const SizedBox(height:16), Text('Bugünün Fetihleri Tamamlandı!', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height:8), Padding(padding: const EdgeInsets.symmetric(horizontal:32), child: Text('Yarın yeni hedeflerle görüşmek üzere, komutanım.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor))), ])).animate().fadeIn(duration:500.ms);

  void _openSearchSheet(BuildContext context){
    showModalBottomSheet(context: context, backgroundColor: AppTheme.cardColor, showDragHandle: true, builder: (ctx){
      String tmpSearch = _search; String tmpSort = _sort;
      return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16,8,16,16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
        Text('Arama ve Sıralama', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height:12),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Görev ara...'), onChanged: (v)=> tmpSearch = v.trim(), controller: TextEditingController(text: _search)),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.sort), labelText: 'Sıralama'),
          value: tmpSort,
          items: const [DropdownMenuItem(value:'önerilen',child:Text('Önerilen')), DropdownMenuItem(value:'ödül',child:Text('Ödül')), DropdownMenuItem(value:'ilerleme',child:Text('İlerleme'))],
          onChanged: (v){ if(v!=null) tmpSort=v; },
        ),
        const SizedBox(height:16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: (){ setState((){ _search = tmpSearch; _sort = tmpSort; }); Navigator.pop(ctx); }, icon: const Icon(Icons.check), label: const Text('Uygula'))),
      ])));
    });
  }

  void _showHelp(BuildContext context){ showModalBottomSheet(context: context, showDragHandle:true, backgroundColor: AppTheme.cardColor, builder: (ctx){ return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20,12,20,24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text('Görev Rehberi', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height:12), Expanded(child: ListView(children:[ ...QuestsScreen.categoryHelp.entries.map((e)=> Padding(padding: const EdgeInsets.only(bottom:12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ const Icon(Icons.label_important_outline,size:18,color:AppTheme.secondaryColor), const SizedBox(width:8), Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium)), ]))), const Divider(), Text('İlerleme Mantığı', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height:8), _helpBullet('Soru / dakika içeren görevler: Hedef sayıya ulaştığında otomatik tamamlanır.'), _helpBullet('Plan görevleri: Haftalık plan ekranında ilgili maddeyi bitir.'), _helpBullet('Deneme görevleri: Deneme ekle ekranından yeni sonuç kaydet.'), _helpBullet('Ziyaret / seri görevleri: Uygulamayı gün içinde tekrar açarak ilerlet.'), _helpBullet('Pomodoro odak görevleri: Odak seansları tamamla.'), ])), const SizedBox(height:12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: ()=>Navigator.pop(ctx), icon: const Icon(Icons.check_circle_outline), label: const Text('Anladım')) ) ]))); }); }
  Widget _helpBullet(String text)=> Padding(padding: const EdgeInsets.only(bottom:6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ const Text('• ', style: TextStyle(color: AppTheme.secondaryColor)), Expanded(child: Text(text)), ]));
}

// Küçük kart görünümü (yatay önerilenler)
class _SmallQuestCard extends StatefulWidget {
  final Quest quest; final String? userId; final Set<String> completedIds; final Map<String,Quest> allQuestsMap; final WidgetRef ref;
  const _SmallQuestCard({required this.quest, required this.userId, required this.completedIds, required this.allQuestsMap, required this.ref});

  @override
  State<_SmallQuestCard> createState() => _SmallQuestCardState();
}

class _SmallQuestCardState extends State<_SmallQuestCard> {
  bool _localRewardClaimed = false;
  bool _isClaimingReward = false;

  @override
  void initState() {
    super.initState();
    _localRewardClaimed = widget.quest.rewardClaimed;
  }

  @override
  void didUpdateWidget(_SmallQuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Quest güncellendiğinde local state'i sıfırla
    if (oldWidget.quest.id != widget.quest.id ||
        oldWidget.quest.rewardClaimed != widget.quest.rewardClaimed) {
      _localRewardClaimed = widget.quest.rewardClaimed;
      _isClaimingReward = false;
    }
  }

  LinearGradient _grad(QuestCategory c){
    switch(c){
      case QuestCategory.practice: return const LinearGradient(colors:[Color(0xFF8E2DE2), Color(0xFF4A00E0)]);
      case QuestCategory.study: return const LinearGradient(colors:[Color(0xFF2193b0), Color(0xFF6dd5ed)]);
      case QuestCategory.engagement: return const LinearGradient(colors:[Color(0xFFf80759), Color(0xFFbc4e9c)]);
      case QuestCategory.consistency: return const LinearGradient(colors:[Color(0xFF00b09b), Color(0xFF96c93d)]);
      case QuestCategory.test_submission: return const LinearGradient(colors:[Color(0xFFf7971e), Color(0xFFffd200)]);
      case QuestCategory.focus: return const LinearGradient(colors:[Color(0xFF00d2ff), Color(0xFF3a7bd5)]);
    }
  }
  @override Widget build(BuildContext context){
    final progress = widget.quest.goalValue > 0
        ? ((widget.quest.currentProgress / widget.quest.goalValue).clamp(0.0, 1.0))
        : 1.0;
    final isCompleted = widget.quest.isCompleted;
    final canClaim = isCompleted && !_localRewardClaimed && widget.userId != null && !_isClaimingReward;

    return Card(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: _grad(widget.quest.category),
          borderRadius: BorderRadius.circular(12)
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Row(children:[
              Icon(
                isCompleted ? Icons.verified_rounded : Icons.local_fire_department,
                color: Colors.white70,
                size: 16
              ),
              const SizedBox(width: 6),
              Text(
                isCompleted ? 'Tamamlandı' : ' +${widget.quest.reward} BP',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
              )
            ]),
            const SizedBox(height: 8),
            Text(
              widget.quest.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white30,
                valueColor: const AlwaysStoppedAnimation(Colors.white)
              )
            ),
            const SizedBox(height: 6),
            Row(children:[
              Expanded(
                child: Text(
                  '${widget.quest.currentProgress}/${widget.quest.goalValue}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)
                )
              ),
              if (canClaim)
                _isClaimingReward
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: () async {
                        setState(() {
                          _isClaimingReward = true;
                        });

                        try {
                          await widget.ref.read(firestoreServiceProvider).claimQuestReward(widget.userId!, widget.quest);

                          // Optimistic update - hemen local state'i güncelle
                          setState(() {
                            _localRewardClaimed = true;
                            _isClaimingReward = false;
                          });

                          // Provider'ı invalidate et
                          widget.ref.invalidate(dailyQuestsProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ödül tahsil edildi.'))
                            );
                          }
                        } catch (e) {
                          // Hata durumunda state'i geri al
                          setState(() {
                            _isClaimingReward = false;
                          });

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ödül alırken hata oluştu: $e'))
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                      label: const Text('Ödül', style: TextStyle(color: Colors.white))
                    )
            ])
          ]
        ),
      )
    );
  }
}
