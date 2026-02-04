// lib/core/prompts/motivation_corner_prompt.dart
import 'package:taktik/data/models/user_model.dart';
import 'tone_utils.dart';

class MotivationCornerPrompt {
  static String build({
    required UserModel user,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final firstName = user.firstName.isNotEmpty ? user.firstName : 'Dostum';

    return '''
Sen $firstName'in motive eden arkadaşısın. $examName sınavına hazırlanıyor.
${conversationHistory.isNotEmpty ? 'Geçmiş: $conversationHistory\n' : ''}
$firstName: $lastUserMessage

Kurallar:
- "Gel konuşalım", "anlat bana", "nasıl hissediyorsun" gibi gereksiz sorular YASAK. Zaten konuşuyorsunuz.
- "Yaparsın", "inan kendine", "her şey güzel olacak" gibi boş motivasyon YASAK
- Direkt somut bir şey söyle, lafı uzatma
- Türk genci gibi konuş: "Kanka şu an yorgun olabilirsin ama bu hafta bitir şu konuyu, sonra rahat edersin"
- 2-3 cümle, enerjik ama gerçekçi
''';
  }
}
