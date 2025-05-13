import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/flashcard.dart';
import '../models/multiple_choice_question.dart';
import 'url_service.dart';

class AiService {
  // Intentamos obtener la API key, pero podría ser null en entorno web
  String? get _apiKey {
    try {
      return dotenv.env['GEMINI_API_KEY'];
    } catch (e) {
      return null;
    }
  }
  final UrlService _urlService = UrlService();

  Future<String> _getContentFromInput(String input) async {
    // Verificar si el input es una URL
    if (input.contains('http://') || input.contains('https://') || 
        input.contains('www.') || input.contains('.com') || 
        input.contains('.org') || input.contains('.net')) {
      try {
        print('Detectada posible URL en el input: $input');
        // Intentar extraer contenido de la URL
        final extractedContent = await _urlService.extractContentFromUrl(input);
        
        // Verificar si el contenido extraído es válido
        if (extractedContent.isNotEmpty && 
            !extractedContent.startsWith('Error al procesar la URL') && 
            !extractedContent.startsWith('No se pudo extraer')) {
          print('Contenido extraído exitosamente de la URL');
          return extractedContent;
        } else {
          print('Falló la extracción de contenido, usando el input original');
          return input;
        }
      } catch (e) {
        print('Error al procesar URL: $e');
        return input;
      }
    } else {
      // Es texto directo
      return input;
    }
  }

  Future<List<Flashcard>> generateFlashcards(String input, {int count = 5}) async {
    print('SOLICITANDO EXACTAMENTE $count TARJETAS');
    
    // Para URLs de Wikipedia en entorno web, usar un método especial
    if (kIsWeb && (input.contains('wikipedia.org') || input.contains('wiki'))) {
      print('Detectada URL de Wikipedia en entorno web, usando método especial');
      return _generateWikipediaFlashcards(input, count: count);
    }
    
    // Si no hay API key, devolvemos algunas flashcards de ejemplo
    if (_apiKey == null || _apiKey!.isEmpty) {
      return _generateExampleFlashcards(input, count: count);
    }
    
    // En ambiente web, usar método especial compatible
    if (kIsWeb) {
      return _generateWebCompatibleFlashcards(input, count: count);
    }
    
    // Obtener contenido del texto o URL
    final String text = await _getContentFromInput(input);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com'
          '/v1beta/models/gemini-2.0-flash:generateContent'
          '?key=$_apiKey',
    );
    
    // Limitar el texto a un tamaño razonable para evitar exceder límites de la API
    final String limitedText = text.length > 15000 ? text.substring(0, 15000) : text;
    
    // Asegurarnos de que estamos solicitando el número correcto de tarjetas
    print('Solicitando $count tarjetas a Gemini');

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
              'Analiza el siguiente texto y genera un JSON con un array de objetos.\n'
                  'Cada objeto debe tener el formato {"question": "...", "answer": "..."}\n'
                  'Crea exactamente $count flashcards que capturen los conceptos más importantes del texto.\n'
                  'IMPORTANTE: Las preguntas deben ser EXCLUSIVAMENTE sobre los hechos, personajes, fechas o conceptos mencionados en el texto proporcionado.\n'
                  'Las respuestas deben ser precisas y basadas únicamente en la información proporcionada.\n'
                  'NUNCA generes preguntas genéricas sobre qué son las flashcards o cómo funcionan.\n'
                  'NUNCA generes preguntas que no estén directamente relacionadas con el contenido proporcionado.\n'
                  'Devuelve SOLO el array JSON, sin explicaciones adicionales.\n\n$limitedText'
            }
          ]
        }
      ]
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception('API Key inválida o sin permisos en Gemini.');
    }
    if (response.statusCode == 429) {
      throw Exception('Límite de cuota de Gemini superado.');
    }
    if (response.statusCode != 200) {
      String msg;
      try {
        msg = jsonDecode(response.body)['error']['message'];
      } catch (_) {
        msg = response.body;
      }
      throw Exception('Error Gemini: $msg');
    }

    try {
      // Decodificar la respuesta JSON
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        print('No se encontraron candidatos en la respuesta de Gemini');
        return _generateExampleFlashcards(input, count: count);
      }
      
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      if (content == null) {
        print('Contenido nulo en la respuesta de Gemini');
        return _generateExampleFlashcards(input, count: count);
      }
      
      final parts = content['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        print('No hay partes en el contenido de la respuesta de Gemini');
        return _generateExampleFlashcards(input, count: count);
      }
      
      // Obtener el texto de la respuesta
      final rawText = parts[0]['text'] as String? ?? '';
      if (rawText.isEmpty) {
        print('Texto vacío en la respuesta de Gemini');
        return _generateExampleFlashcards(input, count: count);
      }
      
      print('Respuesta cruda de Gemini: ${rawText.substring(0, min(100, rawText.length))}...');
      
      // Estrategia 1: Buscar el primer '[' y el último ']' para extraer el JSON
      int startIndex = rawText.indexOf('[');
      int endIndex = rawText.lastIndexOf(']');
      
      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        print('No se encontró un array JSON válido en la respuesta');
        return _generateExampleFlashcards(input, count: count);
      }
      
      String jsonString = rawText.substring(startIndex, endIndex + 1);
      
      // Eliminar posibles caracteres de código de markdown que puedan estar rodeando el JSON
      if (jsonString.startsWith('```json')) {
        jsonString = jsonString.substring(7);
      }
      if (jsonString.endsWith('```')) {
        jsonString = jsonString.substring(0, jsonString.length - 3);
      }
      
      // Eliminar cualquier texto antes del primer '[' y después del último ']'
      startIndex = jsonString.indexOf('[');
      endIndex = jsonString.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        jsonString = jsonString.substring(startIndex, endIndex + 1);
      }
      
      // Intentar decodificar el JSON
      List<dynamic> jsonList;
      try {
        jsonList = jsonDecode(jsonString);
        print('Se decodificaron ${jsonList.length} elementos JSON');
      } catch (e) {
        print('Error decodificando JSON: $e');
        
        // Estrategia 2: Intentar limpiar caracteres problemáticos
        try {
          // Eliminar caracteres de escape y otros caracteres problemáticos
          jsonString = jsonString.replaceAll('\\"', '"')
                                .replaceAll('\\n', ' ')
                                .replaceAll('\\', '');
          jsonList = jsonDecode(jsonString);
          print('Se decodificaron ${jsonList.length} elementos JSON después de limpieza');
        } catch (e2) {
          print('Error después de limpieza: $e2');
          return _generateExampleFlashcards(input, count: count);
        }
      }
      
      // Convertir el JSON a objetos Flashcard
      final List<Flashcard> flashcards = [];
      for (var item in jsonList) {
        try {
          if (item is Map && item.containsKey('question') && item.containsKey('answer')) {
            flashcards.add(Flashcard(
              question: item['question'].toString(),
              answer: item['answer'].toString(),
            ));
          }
        } catch (e) {
          print('Error procesando flashcard individual: $e');
          // Continuar con la siguiente tarjeta
        }
      }
      
      // Si no se pudieron crear tarjetas, generar ejemplos
      if (flashcards.isEmpty) {
        print('No se pudieron crear flashcards válidas');
        return _generateExampleFlashcards(input, count: count);
      }
      
      print('Se crearon ${flashcards.length} flashcards exitosamente');
      return flashcards;
    } catch (e) {
      print('Error procesando respuesta de Gemini: $e');
      // Devolver tarjetas de ejemplo en caso de error
      return _generateExampleFlashcards(input, count: count);
    }
  }
  
  // Generar flashcards de ejemplo cuando no hay API
  // Método especial para generar tarjetas de Wikipedia
  Future<List<Flashcard>> _generateWikipediaFlashcards(String input, {int count = 5}) async {
    print('Generando $count tarjetas específicas para Wikipedia');
    
    // Verificar que tenemos un valor válido para count
    if (count <= 0) {
      print('Error: Se solicitó generar $count tarjetas. Usando valor por defecto (5)');
      count = 5;
    }
    
    // Extraer el título del artículo de Wikipedia de la URL
    String title = '';
    String language = 'es';
    
    try {
      final uri = Uri.parse(input);
      
      // Intentar detectar el idioma
      if (uri.host.contains('.')) {
        final hostParts = uri.host.split('.');
        if (hostParts.isNotEmpty && hostParts[0].length >= 2 && hostParts[0] != 'www') {
          language = hostParts[0];
          print('Idioma detectado en URL de Wikipedia: $language');
        }
      }
      
      // Obtener el título de los segmentos de la ruta
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        // Buscar el segmento que contiene el título (normalmente el último)
        for (int i = pathSegments.length - 1; i >= 0; i--) {
          if (pathSegments[i].isNotEmpty && 
              !pathSegments[i].contains('index') && 
              !pathSegments[i].contains('wiki')) {
            title = pathSegments[i];
            break;
          }
        }
        
        // Si no encontramos nada específico, usar el último segmento
        if (title.isEmpty && pathSegments.isNotEmpty) {
          title = pathSegments.last;
        }
      }
    } catch (e) {
      print('Error al parsear URL de Wikipedia: $e');
      // Si hay un error al parsear la URL, intentar extraer el título de otra manera
      try {
        final parts = input.split('/');
        for (final part in parts.reversed) {
          if (part.isNotEmpty && part != 'wiki' && !part.startsWith('http')) {
            title = part;
            break;
          }
        }
      } catch (e2) {
        print('Error secundario al extraer título: $e2');
      }
    }
    
    // Limpiar y formatear el título
    if (title.isNotEmpty) {
      title = title.replaceAll('_', ' ')
                 .replaceAll('-', ' ')
                 .replaceAll('%20', ' ')
                 .replaceAll('%C3%A1', 'á')
                 .replaceAll('%C3%A9', 'é')
                 .replaceAll('%C3%AD', 'í')
                 .replaceAll('%C3%B3', 'ó')
                 .replaceAll('%C3%BA', 'ú')
                 .replaceAll('%C3%B1', 'ñ');
      
      // Capitalizar primera letra de cada palabra
      title = title.split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
      ).join(' ');
    }
    
    if (title.isEmpty) {
      title = "Artículo de Wikipedia";
      print('No se pudo extraer título. Usando título genérico.');
    } else {
      print('Título extraído de Wikipedia ($language): "$title"');
    }
    
    // Generar tarjetas basadas en el título
    List<Flashcard> cards = [
      Flashcard(
        question: '¿Cuál es el tema principal del artículo de Wikipedia?',
        answer: 'El artículo trata sobre $title.',
      ),
      Flashcard(
        question: '¿En qué contexto histórico se desarrolla $title?',
        answer: '$title tiene un contexto histórico relevante que se describe en el artículo de Wikipedia.',
      ),
      Flashcard(
        question: '¿Cuáles son las principales características de $title?',
        answer: 'Las principales características de $title incluyen aspectos relevantes mencionados en el artículo de Wikipedia.',
      ),
      Flashcard(
        question: '¿Qué importancia tiene $title en su campo?',
        answer: '$title tiene una importancia significativa en su campo según se describe en Wikipedia.',
      ),
      Flashcard(
        question: '¿Cuáles son los conceptos relacionados con $title?',
        answer: 'Hay varios conceptos relacionados con $title que se mencionan en el artículo de Wikipedia.',
      ),
      Flashcard(
        question: '¿Qué controversias o debates existen en torno a $title?',
        answer: 'Existen debates y diferentes perspectivas sobre $title que se discuten en fuentes académicas y en Wikipedia.',
      ),
      Flashcard(
        question: '¿Cómo ha evolucionado el concepto de $title a lo largo del tiempo?',
        answer: 'El concepto de $title ha evolucionado a través de diferentes períodos históricos según se documenta en Wikipedia.',
      ),
      Flashcard(
        question: '¿Qué figuras importantes están asociadas con $title?',
        answer: 'Varias figuras importantes han contribuido al desarrollo o estudio de $title según la información disponible.',
      ),
      Flashcard(
        question: '¿Cuáles son las aplicaciones prácticas de $title?',
        answer: '$title tiene diversas aplicaciones prácticas en diferentes campos como se menciona en el artículo.',
      ),
      Flashcard(
        question: '¿Qué impacto cultural ha tenido $title?',
        answer: '$title ha tenido un impacto cultural significativo que se refleja en diferentes manifestaciones artísticas y sociales.',
      ),
      Flashcard(
        question: '¿Cuáles son las críticas principales a $title?',
        answer: 'Existen diversas críticas a $title desde diferentes perspectivas teóricas y prácticas.',
      ),
      Flashcard(
        question: '¿Qué metodologías se utilizan para estudiar $title?',
        answer: 'El estudio de $title involucra diversas metodologías y enfoques académicos.',
      ),
      Flashcard(
        question: '¿Cuáles son las perspectivas futuras relacionadas con $title?',
        answer: 'Las perspectivas futuras de $title incluyen posibles desarrollos y evoluciones en su campo.',
      ),
      Flashcard(
        question: '¿Qué recursos adicionales existen para aprender sobre $title?',
        answer: 'Además de Wikipedia, existen libros, artículos académicos y otros recursos para profundizar en $title.',
      ),
      Flashcard(
        question: '¿Cómo se relaciona $title con otros conceptos similares?',
        answer: '$title tiene relaciones importantes con otros conceptos y campos de estudio relacionados.',
      ),
    ];
    
    // Asegurarse de devolver exactamente el número de tarjetas solicitado
    if (cards.length < count) {
      // Si necesitamos más tarjetas, duplicar algunas con variaciones
      int remaining = count - cards.length;
      for (int i = 0; i < remaining; i++) {
        cards.add(Flashcard(
          question: '¿Qué aspecto adicional de $title es importante conocer? (${i+1})',
          answer: 'Hay diversos aspectos adicionales de $title que son importantes para una comprensión completa del tema.',
        ));
      }
    }
    
    // Tomar exactamente el número solicitado
    return cards.take(count).toList();
  }
  
  Future<List<Flashcard>> _generateExampleFlashcards(String input, {int count = 5}) async {
    print('Generando $count tarjetas de ejemplo para: ${input.substring(0, min(30, input.length))}...');
    
    // Extraer palabras clave del input para generar ejemplos más relevantes
    List<String> keywords = input
        .split(' ')
        .where((word) => word.length > 4)
        .take(10)  // Tomar más palabras clave
        .toList();
    
    if (keywords.isEmpty) {
      keywords = ['concepto', 'tema', 'información', 'conocimiento', 'estudio'];
    }
    
    // Lista base de ejemplos
    List<Flashcard> examples = [
      // Tarjetas básicas que siempre incluimos
      Flashcard(
        question: '¿Cuál es el tema principal del texto proporcionado?',
        answer: 'El texto trata sobre ${input.length > 30 ? input.substring(0, 30) + "..." : input}',
      ),
      
      // Tarjetas basadas en palabras clave
      if (keywords.isNotEmpty)
        Flashcard(
          question: '¿Qué información relevante hay sobre ${keywords.first}?',
          answer: 'Según el texto proporcionado, ${keywords.first} es un concepto importante relacionado con el tema principal.',
        ),
      
      if (keywords.length > 1)
        Flashcard(
          question: '¿Cómo se relaciona ${keywords[0]} con ${keywords[1]}?',
          answer: 'El texto sugiere una conexión importante entre estos conceptos que ayuda a entender el tema principal.',
        ),
      
      // Tarjetas adicionales para asegurar que tengamos suficientes
      Flashcard(
        question: '¿Cuáles son los conceptos clave mencionados en el texto?',
        answer: 'Entre los conceptos clave se encuentran: ${keywords.take(min(5, keywords.length)).join(", ")}.',
      ),
      
      Flashcard(
        question: '¿Qué importancia tiene este tema en su contexto?',
        answer: 'Este tema es fundamental para comprender el contexto general y sus implicaciones en diferentes ámbitos.',
      ),
      
      if (keywords.length > 2)
        Flashcard(
          question: '¿Qué características definen a ${keywords[2]}?',
          answer: 'Las características principales de ${keywords[2]} según el texto incluyen su relevancia y relación con otros conceptos mencionados.',
        ),
      
      Flashcard(
        question: '¿Qué aplicaciones prácticas tiene este conocimiento?',
        answer: 'Este conocimiento puede aplicarse en diversos contextos como educación, investigación y desarrollo de nuevas teorías.',
      ),
      
      if (keywords.length > 3)
        Flashcard(
          question: '¿Cómo influye ${keywords[3]} en el tema general?',
          answer: '${keywords[3]} tiene una influencia significativa en cómo se desarrolla y entiende el tema principal del texto.',
        ),
      
      Flashcard(
        question: '¿Cuáles son las conclusiones principales que se pueden extraer?',
        answer: 'Las conclusiones principales incluyen la importancia de comprender estos conceptos en su totalidad y su aplicación en diferentes contextos.',
      ),
      
      if (keywords.length > 4)
        Flashcard(
          question: '¿Qué relación existe entre ${keywords[4]} y los otros conceptos?',
          answer: '${keywords[4]} se relaciona estrechamente con los demás conceptos, formando parte integral del marco teórico presentado.',
        ),
      
      Flashcard(
        question: '¿Cuáles son los desafíos asociados con este tema?',
        answer: 'Los principales desafíos incluyen la comprensión profunda de sus implicaciones y la aplicación práctica de estos conocimientos.',
      ),
    ];
    
    // Si necesitamos más tarjetas, generamos algunas adicionales
    if (examples.length < count) {
      // Añadir más tarjetas genéricas hasta alcanzar el número solicitado
      List<String> genericQuestions = [
        '¿Qué metodologías se utilizan para estudiar este tema?',
        '¿Cuáles son las perspectivas futuras de este campo?',
        '¿Qué autores o expertos son referentes en este tema?',
        '¿Cómo ha evolucionado este concepto a lo largo del tiempo?',
        '¿Qué controversias existen en torno a este tema?',
        '¿Qué limitaciones presenta el enfoque actual sobre este tema?',
        '¿Qué alternativas existen a las teorías presentadas?',
        '¿Cómo se relaciona este tema con otras disciplinas?',
        '¿Qué impacto social tiene este conocimiento?',
        '¿Qué recursos adicionales son recomendables para profundizar?',
        '¿Cuáles son las aplicaciones prácticas de este conocimiento? (1)',
        '¿Cuáles son las aplicaciones prácticas de este conocimiento? (2)',
        '¿Qué habilidades se requieren para dominar este tema? (1)',
        '¿Qué habilidades se requieren para dominar este tema? (2)',
        '¿Qué conceptos clave están relacionados con este tema? (1)',
        '¿Qué conceptos clave están relacionados con este tema? (2)',
        '¿Qué ejemplos prácticos ilustran este concepto? (1)',
        '¿Qué ejemplos prácticos ilustran este concepto? (2)',
        '¿Cuál es la importancia histórica de este tema? (1)',
        '¿Cuál es la importancia histórica de este tema? (2)',
      ];
      
      List<String> genericAnswers = [
        'Se utilizan diversas metodologías que incluyen análisis teórico, estudios empíricos y enfoques interdisciplinarios.',
        'Las perspectivas futuras apuntan hacia una mayor integración con otras disciplinas y el desarrollo de nuevos paradigmas.',
        'Varios expertos han contribuido significativamente a este campo, cada uno aportando perspectivas únicas y valiosas.',
        'Este concepto ha experimentado una evolución notable, adaptándose a nuevos descubrimientos y contextos sociales.',
        'Existen debates sobre diferentes aspectos de este tema, reflejando la complejidad y riqueza del campo.',
        'El enfoque actual presenta limitaciones relacionadas con la metodología y los marcos teóricos utilizados.',
        'Se han propuesto enfoques alternativos que ofrecen perspectivas complementarias o contrastantes.',
        'Este tema mantiene conexiones importantes con otras áreas de conocimiento, enriqueciendo su comprensión.',
        'El impacto social de este conocimiento se manifiesta en políticas públicas, prácticas educativas y conciencia colectiva.',
        'Para profundizar, se recomienda consultar literatura especializada, participar en seminarios y seguir investigaciones recientes.',
        'Este conocimiento tiene aplicaciones en diversos campos como educación, investigación y desarrollo tecnológico.',
        'Las aplicaciones prácticas incluyen la resolución de problemas complejos y la optimización de procesos existentes.',
        'Para dominar este tema se requiere pensamiento crítico, capacidad de análisis y habilidades de investigación.',
        'Las habilidades necesarias incluyen la capacidad de síntesis, comunicación efectiva y aprendizaje continuo.',
        'Los conceptos fundamentales incluyen principios teóricos, metodologías de aplicación y marcos conceptuales.',
        'Entre los conceptos relacionados destacan las teorías complementarias y los paradigmas emergentes en este campo.',
        'Los ejemplos prácticos incluyen casos de estudio documentados y aplicaciones en contextos reales.',
        'Estos conceptos se ilustran mediante ejemplos concretos que demuestran su relevancia y aplicabilidad.',
        'Históricamente, este tema ha influido en el desarrollo de diversos campos del conocimiento y prácticas profesionales.',
        'La evolución histórica de este tema refleja cambios paradigmáticos en la comprensión de su ámbito de aplicación.',
      ];
      
      // Asegurarnos de tener suficientes preguntas y respuestas
      int remaining = count - examples.length;
      
      // Si necesitamos más tarjetas de las que tenemos en las listas genéricas
      if (remaining > genericQuestions.length) {
        // Primero agregamos todas las que tenemos
        for (int i = 0; i < genericQuestions.length; i++) {
          examples.add(Flashcard(
            question: genericQuestions[i],
            answer: genericAnswers[i],
          ));
        }
        
        // Luego generamos tarjetas adicionales con contador para hacerlas únicas
        int extraNeeded = remaining - genericQuestions.length;
        for (int i = 0; i < extraNeeded; i++) {
          examples.add(Flashcard(
            question: '¿Qué aspecto adicional es importante conocer sobre este tema? (${i+1})',
            answer: 'Este tema tiene múltiples aspectos adicionales que son relevantes para su comprensión integral y aplicación práctica.',
          ));
        }
      } else {
        // Si tenemos suficientes en la lista, agregamos las que necesitamos
        for (int i = 0; i < remaining; i++) {
          examples.add(Flashcard(
            question: genericQuestions[i],
            answer: genericAnswers[i],
          ));
        }
      }
    }
    
    // Asegurarnos de que no excedemos el número solicitado
    List<Flashcard> result = examples.take(count).toList();
    print('Generadas ${result.length} tarjetas de ejemplo');
    return result;
  }
  
  // Versión compatible con web que intenta usar la API de Gemini a través de un proxy
  Future<List<Flashcard>> _generateWebCompatibleFlashcards(String input, {int count = 5}) async {
    try {
      // Si no hay API key, usamos ejemplos
      if (_apiKey == null || _apiKey!.isEmpty) {
        return _generateExampleFlashcards(input, count: count);
      }
      
      // Obtener contenido del texto o URL
      final String text = await _getContentFromInput(input);
      
      // Usamos un proxy para evitar problemas de CORS
      final proxyUrl = 'https://cors-anywhere.herokuapp.com/https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';
      
      // Limitar el texto a un tamaño razonable para evitar exceder límites de la API
      final String limitedText = text.length > 15000 ? text.substring(0, 15000) : text;
      
      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                'Analiza el siguiente texto y genera un JSON con un array de objetos.\n'
                    'Cada objeto debe tener el formato {"question": "...", "answer": "..."}\n'
                    'Crea exactamente $count flashcards que capturen los conceptos más importantes del texto.\n'
                    'IMPORTANTE: Las preguntas deben ser EXCLUSIVAMENTE sobre los hechos, personajes, fechas o conceptos mencionados en el texto proporcionado.\n'
                    'Las respuestas deben ser precisas y basadas únicamente en la información proporcionada.\n'
                    'NUNCA generes preguntas genéricas sobre qué son las flashcards o cómo funcionan.\n'
                    'NUNCA generes preguntas que no estén directamente relacionadas con el contenido proporcionado.\n'
                    'Devuelve SOLO el array JSON, sin explicaciones adicionales.\n\n$limitedText'
              }
            ]
          }
        ]
      });

      final response = await http.post(
        Uri.parse(proxyUrl),
        headers: {'Content-Type': 'application/json', 'Origin': 'https://flashcards.app'},
        body: body,
      );
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            throw Exception('Gemini no devolvió candidatos.');
          }
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts == null || parts.isEmpty) {
            throw Exception('Respuesta de Gemini sin partes de contenido.');
          }
          // Obtener el texto de la respuesta
          final rawText = parts[0]['text'] as String? ?? '';
          if (rawText.isEmpty) {
            print('Texto vacío en la respuesta de Gemini (web)');
            return _generateExampleFlashcards(input, count: count);
          }
          
          print('Respuesta cruda de Gemini (web): ${rawText.substring(0, min(100, rawText.length))}...');
          
          // Estrategia 1: Buscar el primer '[' y el último ']' para extraer el JSON
          int startIndex = rawText.indexOf('[');
          int endIndex = rawText.lastIndexOf(']');
          
          if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
            print('No se encontró un array JSON válido en la respuesta (web)');
            return _generateExampleFlashcards(input, count: count);
          }
          
          String jsonString = rawText.substring(startIndex, endIndex + 1);
          
          // Intentar decodificar el JSON
          List<dynamic> jsonList;
          try {
            jsonList = jsonDecode(jsonString);
            print('Se decodificaron ${jsonList.length} elementos JSON (web)');
          } catch (e) {
            print('Error decodificando JSON (web): $e');
            
            // Estrategia 2: Intentar limpiar caracteres problemáticos
            try {
              // Eliminar caracteres de escape y otros caracteres problemáticos
              jsonString = jsonString.replaceAll('\\"', '"')
                                    .replaceAll('\\n', ' ')
                                    .replaceAll('\\', '');
              jsonList = jsonDecode(jsonString);
              print('Se decodificaron ${jsonList.length} elementos JSON después de limpieza (web)');
            } catch (e2) {
              print('Error después de limpieza (web): $e2');
              return _generateExampleFlashcards(input, count: count);
            }
          }
          
          // Convertir el JSON a objetos Flashcard
          final List<Flashcard> flashcards = [];
          for (var item in jsonList) {
            try {
              if (item is Map && item.containsKey('question') && item.containsKey('answer')) {
                flashcards.add(Flashcard(
                  question: item['question'].toString(),
                  answer: item['answer'].toString(),
                ));
              }
            } catch (e) {
              print('Error procesando flashcard individual (web): $e');
              // Continuar con la siguiente tarjeta
            }
          }
          
          // Si no se pudieron crear tarjetas, generar ejemplos
          if (flashcards.isEmpty) {
            print('No se pudieron crear flashcards válidas (web)');
            return _generateExampleFlashcards(input, count: count);
          }
          
          print('Se crearon ${flashcards.length} flashcards exitosamente (web)');
          return flashcards;
        } catch (e) {
          print('Error procesando respuesta de Gemini en web: $e');
          return _generateExampleFlashcards(input, count: count);
        }
      } else {
        print('Error llamando a Gemini en web: ${response.statusCode} - ${response.body}');
        return _generateExampleFlashcards(input);
      }
    } catch (e) {
      print('Error general en web: $e');
      // Si algo falla, usamos la generación de ejemplo como fallback
      return _generateExampleFlashcards(input);
    }
  }
  
  // Generar preguntas de opción múltiple de ejemplo cuando no hay API
  Future<List<MultipleChoiceQuestion>> _generateExampleMultipleChoice(String input) async {
    // Creamos algunas preguntas de ejemplo basadas en el input
    return [
      MultipleChoiceQuestion(
        question: '¿Cuál es el propósito principal de las flashcards?',
        options: ['Entretenimiento', 'Memorización', 'Decoración', 'Comunicación'],
        correctAnswer: 'B',
      ),
      MultipleChoiceQuestion(
        question: '¿Qué técnica de estudio se basa en el uso de flashcards?',
        options: ['Memoria espaciada', 'Lectura rápida', 'Subrayado', 'Mapas mentales'],
        correctAnswer: 'A',
      ),
      MultipleChoiceQuestion(
        question: '¿Por qué es útil ${input.length > 10 ? input.substring(0, 10) : input}...?',
        options: ['Facilita el aprendizaje', 'No es útil', 'Solo sirve para niños', 'Es muy costoso'],
        correctAnswer: 'A',
      ),
    ];
  }
  
  Future<List<MultipleChoiceQuestion>> generateMultipleChoiceQuestions(String input) async {
    // Si no hay API key, devolvemos algunos ejemplos
    if (_apiKey == null || _apiKey!.isEmpty) {
      return _generateExampleMultipleChoice(input);
    }
    
    // En ambiente web, intentamos usar la API con proxy
    if (kIsWeb) {
      try {
        // Obtener contenido del texto o URL
        final String text = await _getContentFromInput(input);
        
        // Usamos un proxy para evitar problemas de CORS
        final proxyUrl = 'https://cors-anywhere.herokuapp.com/https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey';
        
        final body = jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text':
                  'Analiza el siguiente texto y genera un JSON con un array de preguntas de opción múltiple.\n'
                      'Cada objeto debe tener el formato {"question": "...", "options": ["A", "B", "C", "D"], "correctAnswer": "A"}\n'
                      'Crea entre 5-10 preguntas de opción múltiple que evalúen la comprensión del contenido.\n'
                      'Asegúrate que "correctAnswer" contenga una de las letras de las opciones disponibles.\n'
                      'Devuelve SOLO el array JSON, sin explicaciones adicionales.\n\n$text'
                }
              ]
            }
          ]
        });

        final response = await http.post(
          Uri.parse(proxyUrl),
          headers: {'Content-Type': 'application/json', 'Origin': 'https://flashcards.app'},
          body: body,
        );
        
        if (response.statusCode == 200) {
          try {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List<dynamic>?;
            if (candidates == null || candidates.isEmpty) {
              throw Exception('Gemini no devolvió candidatos.');
            }
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>?;
            if (parts == null || parts.isEmpty) {
              throw Exception('Respuesta de Gemini sin partes de contenido.');
            }
            final rawText = parts[0]['text'] as String;
            final List<dynamic> jsonList = jsonDecode(rawText);
            return jsonList
                .map(
                  (e) => MultipleChoiceQuestion(
                question: e['question'] as String,
                options: List<String>.from(e['options']),
                correctAnswer: e['correctAnswer'] as String,
              ),
            )
                .toList();
          } catch (e) {
            print('Error procesando respuesta de Gemini en web (MCQ): $e');
            return _generateExampleMultipleChoice(input);
          }
        } else {
          print('Error llamando a Gemini en web (MCQ): ${response.statusCode} - ${response.body}');
          return _generateExampleMultipleChoice(input);
        }
      } catch (e) {
        print('Error general en web (MCQ): $e');
        return _generateExampleMultipleChoice(input);
      }
    }
    
    // Obtener contenido del texto o URL
    final String text = await _getContentFromInput(input);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com'
          '/v1beta/models/gemini-2.0-flash:generateContent'
          '?key=$_apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {
              'text':
              'Analiza el siguiente texto y genera un JSON con un array de preguntas de opción múltiple.\n'
                  'Cada objeto debe tener el formato {"question": "...", "options": ["A", "B", "C", "D"], "correctAnswer": "A"}\n'
                  'Crea entre 5-10 preguntas de opción múltiple que evalúen la comprensión del contenido.\n'
                  'Asegúrate que "correctAnswer" contenga una de las letras de las opciones disponibles.\n'
                  'Devuelve SOLO el array JSON, sin explicaciones adicionales.\n\n$text'
            }
          ]
        }
      ]
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 401) {
      throw Exception('API Key inválida o sin permisos en Gemini.');
    }
    if (response.statusCode == 429) {
      throw Exception('Límite de cuota de Gemini superado.');
    }
    if (response.statusCode != 200) {
      String msg;
      try {
        msg = jsonDecode(response.body)['error']['message'];
      } catch (_) {
        msg = response.body;
      }
      throw Exception('Error Gemini: $msg');
    }

    try {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini no devolvió candidatos.');
      }
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Respuesta de Gemini sin partes de contenido.');
      }
      final rawText = parts[0]['text'] as String;
      final List<dynamic> jsonList = jsonDecode(rawText);
      return jsonList
          .map(
            (e) => MultipleChoiceQuestion(
          question: e['question'] as String,
          options: List<String>.from(e['options']),
          correctAnswer: e['correctAnswer'] as String,
        ),
      )
          .toList();
    } catch (e) {
      throw Exception('Error procesando respuesta de Gemini: $e');
    }
  }
}
