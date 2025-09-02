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
enum _QuestFilter { all, daily, weekly, monthly }

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
    final isCompleted=quest.isCompleted; final progress=quest.goalValue>0?((quest.currentProgress/quest.goalValue).clamp(0.0,1.0)):1.0; final locked=!isCompleted && quest.prerequisiteIds.isNotEmpty && !quest.prerequisiteIds.every((id)=>completedIds.contains(id));
    // ödül butonu durumunu doğrudan UI koşullarında kullanıyoruz
    return Card(margin: const EdgeInsets.only(bottom:16), clipBehavior: Clip.antiAlias, color: isCompleted?AppTheme.cardColor.withValues(alpha:0.5):AppTheme.cardColor, child: InkWell(
      onTap: (isCompleted||locked)?(){ if(locked){
        final names = quest.prerequisiteIds.map((id)=> allQuestsMap[id]?.title ?? id).toList();
        final msg = names.isEmpty? 'Önce önkoşul görev(ler)ini tamamla' : 'Önkoşul: '+names.join(', ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg))); }
      }:(){ if(userId!=null){ref.read(analyticsLoggerProvider).logQuestEvent(userId: userId!, event:'quest_tap', data:{'questId':quest.id,'category':quest.category.name});}
      String target=quest.actionRoute; if(target=='/coach'){ final subjectTag=quest.tags.firstWhere((t)=>t.startsWith('subject:'), orElse:()=>'' ); if(subjectTag.isNotEmpty){ final subj=subjectTag.split(':').sublist(1).join(':'); target=Uri(path:'/coach', queryParameters:{'subject':subj}).toString(); }} context.go(target); },
      child: Stack(children:[
        Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
            CircleAvatar(backgroundColor: isCompleted?AppTheme.successColor.withValues(alpha:0.2):AppTheme.secondaryColor.withValues(alpha:0.2), child: Icon(_getIconForCategory(quest.category), color: isCompleted?AppTheme.successColor:AppTheme.secondaryColor)), const SizedBox(width:16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              Text(quest.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: isCompleted?AppTheme.secondaryTextColor:Colors.white)),
              const SizedBox(height:4),
              Text(quest.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
            ])),
          ]),
          const SizedBox(height:8),
          Wrap(spacing:8, runSpacing:4, children:[
            ..._buildPriorityBadges(context, quest, locked:locked, prereqNames: quest.prerequisiteIds.map((id)=>allQuestsMap[id]?.title??id).toList()),
            if(quest.id.startsWith('schedule_')) Chip(label: const Text('Plan'), visualDensity: VisualDensity.compact, backgroundColor: Colors.blueGrey.withValues(alpha:0.3), labelStyle: const TextStyle(fontSize:12)),
            Chip(avatar: const Icon(Icons.star_rounded,color:Colors.amber,size:16), label: Text('+${quest.reward} BP'), visualDensity: VisualDensity.compact, backgroundColor: AppTheme.primaryColor.withValues(alpha:0.4)),
          ]),
          const SizedBox(height:8),
          if(!isCompleted) Row(children:[ Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value:progress,minHeight:8, backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha:0.3), valueColor: const AlwaysStoppedAnimation(AppTheme.secondaryColor)))), const SizedBox(width:12), Text('${quest.currentProgress} / ${quest.goalValue}', style: const TextStyle(fontWeight: FontWeight.bold)),]),
          const SizedBox(height:8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
            if(isCompleted && quest.rewardClaimed) Row(children: const [Text('Fethedildi!', style: TextStyle(color: AppTheme.successColor,fontWeight: FontWeight.bold)), SizedBox(width:4), Icon(Icons.check_circle_rounded,color:AppTheme.successColor,size:20)]).animate().fadeIn().scale(delay:150.ms, curve: Curves.easeOutBack),
            if(isCompleted && !quest.rewardClaimed) Expanded(child: ElevatedButton.icon(onPressed: userId==null? null : () async {
              await ref.read(firestoreServiceProvider).claimQuestReward(userId!, quest);
              ref.invalidate(dailyQuestsProvider);
              if(context.mounted){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ödül tahsil edildi.'))); }
            }, icon: const Icon(Icons.card_giftcard_rounded), label: const Text('Ödülü Al!'), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, foregroundColor: AppTheme.primaryColor))),
            if(!isCompleted) const Row(children:[Text('Yola Koyul', style: TextStyle(color: AppTheme.secondaryTextColor)), SizedBox(width:4), Icon(Icons.arrow_forward, color: AppTheme.secondaryTextColor, size:16)])
          ]),
          const SizedBox(height:4),
          _QuestHintLine(quest: quest),
          _buildChainSegments(quest),
        ])),
        if(locked) Positioned.fill(child: Container(color: Colors.black.withValues(alpha:0.45), child: const Center(child: Icon(Icons.lock,color:Colors.white70,size:40))))
      ]),
    ));
  }
}
class _IssueBanner extends StatelessWidget { final VoidCallback onClose; const _IssueBanner({required this.onClose}); @override Widget build(BuildContext context){ return Card(color: AppTheme.accentColor.withValues(alpha:0.15), child: Padding(padding: const EdgeInsets.symmetric(horizontal:12,vertical:10), child: Row(children:[const Icon(Icons.cloud_off,color:AppTheme.accentColor), const SizedBox(width:12), const Expanded(child: Text('Görev üretimi bağlantı sorunları nedeniyle önbellekten gösteriliyor.', style: TextStyle(color: AppTheme.secondaryTextColor,fontSize:12))), IconButton(onPressed:onClose, icon: const Icon(Icons.close,size:18,color:AppTheme.secondaryTextColor))] ),)); }}
class _SummaryBar extends ConsumerWidget { final List<Quest> quests; final dynamic user; const _SummaryBar({required this.quests, required this.user}); @override Widget build(BuildContext context, WidgetRef ref){ final total=quests.where((q)=>q.type==QuestType.daily).length; final done=quests.where((q)=>q.type==QuestType.daily && q.isCompleted).length; final weeklyTotal=quests.where((q)=>q.type==QuestType.weekly).length; final weeklyDone=quests.where((q)=>q.type==QuestType.weekly && q.isCompleted).length; final monthlyTotal=quests.where((q)=>q.type==QuestType.monthly).length; final monthlyDone=quests.where((q)=>q.type==QuestType.monthly && q.isCompleted).length; final focusMinutes=quests.where((q)=>q.category==QuestCategory.focus).fold<int>(0,(s,q)=>s+q.currentProgress); final practiceSolved=quests.where((q)=>q.category==QuestCategory.practice).fold<int>(0,(s,q)=>s+q.currentProgress); double planRatio=0; try{ final today=DateTime.now(); final completed=ref.watch(completedTasksForDateProvider(today)).maybeWhen(data:(list)=>list.length, orElse: ()=>0); final planTotalRaw=quests.where((q)=>q.id.startsWith('schedule_')).length; final planTotal=planTotalRaw==0?1:planTotalRaw; planRatio=completed/planTotal; }catch(_){ }
return Card(margin: const EdgeInsets.only(bottom:12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Row(children:[ Expanded(child:_metric('Günlük', '$done/$total')), Expanded(child:_metric('Haftalık', '$weeklyDone/$weeklyTotal')), Expanded(child:_metric('Aylık', '$monthlyDone/$monthlyTotal')), Expanded(child:_metric('Plan %','${(planRatio*100).round()}%')), Expanded(child:_metric('Odak dk',focusMinutes.toString())), Expanded(child:_metric('Soru',practiceSolved.toString())), ]), const SizedBox(height:8), LinearProgressIndicator(value: total==0?0.0:done/total, minHeight:6, backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha:0.25), valueColor: const AlwaysStoppedAnimation(AppTheme.secondaryColor)), ]))); }
Widget _metric(String l,String v)=>Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(l, style: const TextStyle(fontSize:11,color:AppTheme.secondaryTextColor)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold)), ]);
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
  _QuestFilter _filter = _QuestFilter.all;
  @override void initState(){ super.initState(); _confettiController=ConfettiController(duration: const Duration(seconds:1)); }
  @override void dispose(){ _confettiController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context){ final loadAsync=ref.watch(dailyQuestsProvider); final quests=ref.watch(optimizedDailyQuestsProvider); final user=ref.watch(userProfileProvider).value; ref.listen<List<Quest>>(optimizedDailyQuestsProvider,(prev,next){ if(prev==null||prev.isEmpty) return; if(next.where((q)=>q.isCompleted).length>prev.where((q)=>q.isCompleted).length){ _confettiController.play(); }}); final isLoading=loadAsync.isLoading && quests.isEmpty; return Scaffold(appBar: AppBar(title: const Text('Fetih Kütüğü'), actions:[ IconButton(tooltip:'Görev Rehberi', icon: const Icon(Icons.help_center_outlined), onPressed: ()=>_showHelp(context)), IconButton(tooltip:'Görevleri Yenile', icon: const Icon(Icons.refresh_rounded), onPressed: user==null?null:() async { await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} ) ]), body: Stack(alignment: Alignment.topCenter, children:[ if(isLoading) const Center(child:CircularProgressIndicator(color: AppTheme.secondaryColor)) else if(quests.isEmpty) _buildEmptyState(context) else _buildQuestList(context,quests,user), ConfettiWidget(confettiController:_confettiController, blastDirectionality: BlastDirectionality.explosive, shouldLoop:false, colors: const [AppTheme.secondaryColor, AppTheme.successColor, Colors.white]), ])); }
  Widget _buildFilterChips(BuildContext context){
    Widget chip(String label, _QuestFilter val){ final sel = _filter==val; return ChoiceChip(label: Text(label), selected: sel, onSelected: (_){ setState(()=> _filter = val); }, selectedColor: AppTheme.secondaryColor.withValues(alpha:0.25), labelStyle: TextStyle(color: sel? Colors.white : AppTheme.secondaryTextColor)); }
    return Wrap(spacing:8, runSpacing:4, children:[ chip('Tümü', _QuestFilter.all), chip('Günlük', _QuestFilter.daily), chip('Haftalık', _QuestFilter.weekly), chip('Aylık', _QuestFilter.monthly) ]);
  }
  Widget _emptySection(BuildContext context, {required String title, required String desc, required VoidCallback onRefresh}){
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height:6), Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)), const SizedBox(height:12), Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(onPressed:onRefresh, icon: const Icon(Icons.autorenew), label: const Text('Görevleri Getir'))), ])));
  }
  Widget _buildQuestList(BuildContext context,List<Quest> quests,user){ final issue=ref.watch(questGenerationIssueProvider); final weekly=quests.where((q)=>q.type==QuestType.weekly).toList(); final monthly=quests.where((q)=>q.type==QuestType.monthly).toList(); final completed=quests.where((q)=>q.isCompleted && q.type==QuestType.daily).toList(); final active=quests.where((q)=>!q.isCompleted && q.type==QuestType.daily).toList(); final completedIds=quests.where((q)=>q.isCompleted).map((q)=>q.id).toSet(); final allMap={for(final q in quests) q.id:q}; final analytics=ref.read(analyticsLoggerProvider); for(final q in quests){ if(!_loggedViews.contains(q.id)){ _loggedViews.add(q.id); if(user!=null){ analytics.logQuestEvent(userId:user.id, event:'quest_view', data:{'questId':q.id,'category':q.category.name,'difficulty':q.difficulty.name}); } }} final listChild=ListView(padding: const EdgeInsets.fromLTRB(16,16,16,120), children:[ _SummaryBar(quests:quests,user:user), if(issue) _IssueBanner(onClose: ()=> ref.read(questGenerationIssueProvider.notifier).state=false),
        Padding(padding: const EdgeInsets.only(bottom:12), child: _buildFilterChips(context)),
        if(_filter==_QuestFilter.all) _buildBannerIfNeeded(context,active,completed),
        if(_filter==_QuestFilter.all || _filter==_QuestFilter.weekly)...[
          const _SectionHeader(title:'Haftalık Sefer'),
          if(weekly.isEmpty) _emptySection(context, title: 'Haftalık görev yok', desc: 'Haftalık görevleriniz oluşturulmadı. Yenile ile anında oluşturabilirsiniz.', onRefresh: () async { if(user!=null){ await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} }),
          ...weekly.map((q)=>QuestCard(quest:q,completedIds:completedIds,userId:user?.id,allQuestsMap:allMap,ref:ref)), const SizedBox(height:16)
        ],
        if(_filter==_QuestFilter.all || _filter==_QuestFilter.monthly)...[
          const _SectionHeader(title:'Aylık Sefer'),
          if(monthly.isEmpty) _emptySection(context, title: 'Aylık görev yok', desc: 'Aylık seferleriniz oluşturulmadı. Yenile ile anında oluşturabilirsiniz.', onRefresh: () async { if(user!=null){ await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} }),
          ...monthly.map((q)=>QuestCard(quest:q,completedIds:completedIds,userId:user?.id,allQuestsMap:allMap,ref:ref)), const SizedBox(height:16)
        ],
        if(_filter==_QuestFilter.all || _filter==_QuestFilter.daily)...[
          const _SectionHeader(title:'Günlük Emirler'),
          if(active.isEmpty) _emptySection(context, title: 'Günlük görev yok', desc: 'Bugün için görev bulunamadı. Yenile ile yeni görevleri getir.', onRefresh: () async { if(user!=null){ await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} }),
          ...active.map((q)=>QuestCard(quest:q,completedIds:completedIds,userId:user?.id,allQuestsMap:allMap,ref:ref))
        ],
         if(completed.isNotEmpty)...[ _SectionHeader(title:'Fethedilenler (${completed.length})'), ...completed.map((q)=>QuestCard(quest:q,completedIds:completedIds,userId:user?.id,allQuestsMap:allMap,ref:ref))], const SizedBox(height:24) ]).animate().fadeIn(duration:400.ms).slideY(begin:0.15); return RefreshIndicator(onRefresh: () async { if(user!=null){ await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force:true); ref.invalidate(dailyQuestsProvider);} }, child:listChild); }
  Widget _buildEmptyState(BuildContext context)=> Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[ const Icon(Icons.shield_moon_rounded,size:80,color:AppTheme.secondaryTextColor), const SizedBox(height:16), Text('Bugünün Fetihleri Tamamlandı!', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height:8), Padding(padding: const EdgeInsets.symmetric(horizontal:32), child: Text('Yarın yeni hedeflerle görüşmek üzere, komutanım.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor))), ])).animate().fadeIn(duration:500.ms);
  Widget _buildBannerIfNeeded(BuildContext context,List<Quest> active,List<Quest> completed){ if(active.isEmpty) return const SizedBox.shrink(); final categories=active.map((e)=>e.category).toSet(); if(categories.length<2) return const SizedBox.shrink(); return Card(color: AppTheme.primaryColor.withValues(alpha:0.35), child: Padding(padding: const EdgeInsets.all(12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ const Icon(Icons.info_outline,color:AppTheme.secondaryColor), const SizedBox(width:12), Expanded(child: Text('Birden fazla kategori açıldı. Her kategori farklı bir gelişim alanını temsil eder. Karttaki kısa ipuçlarını oku ve ilgili ekrana gitmek için dokun.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor))), IconButton(icon: const Icon(Icons.help_outline,size:20,color:AppTheme.secondaryTextColor), onPressed: ()=>_showHelp(context), tooltip:'Kategori Açıklamaları') ]))); }
  void _showHelp(BuildContext context){ showModalBottomSheet(context: context, showDragHandle:true, backgroundColor: AppTheme.cardColor, builder: (ctx){ return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20,12,20,24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[ Text('Görev Rehberi', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height:12), Expanded(child: ListView(children:[ ...QuestsScreen.categoryHelp.entries.map((e)=> Padding(padding: const EdgeInsets.only(bottom:12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ const Icon(Icons.label_important_outline,size:18,color:AppTheme.secondaryColor), const SizedBox(width:8), Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium)), ]))), const Divider(), Text('İlerleme Mantığı', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height:8), _helpBullet('Soru / dakika içeren görevler: Hedef sayıya ulaştığında otomatik tamamlanır.'), _helpBullet('Plan görevleri: Haftalık plan ekranında ilgili maddeyi bitir.'), _helpBullet('Deneme görevleri: Deneme ekle ekranından yeni sonuç kaydet.'), _helpBullet('Ziyaret / seri görevleri: Uygulamayı gün içinde tekrar açarak ilerlet.'), _helpBullet('Pomodoro odak görevleri: Odak seansları tamamla.'), ])), const SizedBox(height:12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: ()=>Navigator.pop(ctx), icon: const Icon(Icons.check_circle_outline), label: const Text('Anladım')) ) ]))); }); }
  Widget _helpBullet(String text)=> Padding(padding: const EdgeInsets.only(bottom:6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[ const Text('• ', style: TextStyle(color: AppTheme.secondaryColor)), Expanded(child: Text(text)), ]));
}

// ===================== ANA EKRAN =====================
