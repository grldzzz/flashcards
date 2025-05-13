import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

class UrlService {
  /// Extrae el contenido de texto de una URL
  Future<String> extractContentFromUrl(String url) async {
    try {
      print('Extrayendo contenido de URL: $url');
      
      // Asegurarse de que la URL tenga el esquema correcto
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      
      // En caso de web, debemos usar un proxy para evitar problemas de CORS
      if (kIsWeb) {
        return await _extractWithCorsProxy(url);
      }
      
      // Verificar que la URL es válida
      final uri = Uri.parse(url);
      
      // Realizar la petición HTTP con un timeout razonable
      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Tiempo de espera agotado al acceder a la URL'),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Error al acceder a la URL (${response.statusCode})');
      }
      
      // Parsear el HTML
      final document = parser.parse(response.body);
      
      // Extraer el contenido de texto relevante
      final String extractedText = _extractMainContent(document, url);
      
      if (extractedText.isEmpty) {
        print('No se pudo extraer contenido de la URL: $url');
        return 'No se pudo extraer contenido de la URL: $url. Por favor intenta con otro enlace o introduce texto directamente.';
      }
      
      print('Contenido extraído exitosamente (${extractedText.length} caracteres)');
      return extractedText;
    } catch (e) {
      print('Error al extraer contenido de URL: $e');
      if (e.toString().contains('Scheme not found')) {
        throw Exception('URL no válida. Asegúrate de incluir http:// o https://');
      }
      // En lugar de propagar el error, devolvemos un mensaje descriptivo
      return 'Error al procesar la URL: ${e.toString()}. Por favor intenta con otro enlace o introduce texto directamente.';
    }
  }
  
  // Método para extraer contenido usando un proxy en web para evitar CORS
  Future<String> _extractWithCorsProxy(String url) async {
    try {
      print('Usando proxy CORS para extraer contenido de: $url');
      
      // Para Wikipedia, podemos extraer información del título de la URL directamente
      if (url.contains('wikipedia.org')) {
        print('URL de Wikipedia detectada en entorno web');
        return _extractWikipediaInfoFromUrl(url);
      }
      
      // Intentar con diferentes servicios de proxy en caso de que uno falle
      final List<String> proxyUrls = [
        'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
        'https://corsproxy.io/?${Uri.encodeComponent(url)}',
        'https://cors-anywhere.herokuapp.com/$url',
        'https://cors-proxy.htmldriven.com/?url=${Uri.encodeComponent(url)}',
      ];
      
      // Intentar con cada proxy
      for (final proxyUrl in proxyUrls) {
        try {
          print('Intentando con proxy: $proxyUrl');
          final response = await http.get(Uri.parse(proxyUrl)).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado con el proxy'),
          );
          
          if (response.statusCode == 200) {
            // Verificar si la respuesta contiene contenido válido
            if (response.body.length > 500) { // Asegurarnos de que hay suficiente contenido
              // Parsear el HTML
              final document = parser.parse(response.body);
              
              // Extraer el contenido de texto relevante
              final String extractedText = _extractMainContent(document, url);
              
              if (extractedText.isNotEmpty) {
                print('Contenido extraído exitosamente a través del proxy');
                return extractedText;
              }
            } else {
              print('Respuesta demasiado corta del proxy: ${response.body.length} bytes');
            }
          }
          print('Proxy falló con código: ${response.statusCode}');
        } catch (e) {
          print('Error con este proxy: $e');
          // Continuar con el siguiente proxy
        }
      }
      
      // Si llegamos aquí, todos los proxies fallaron
      print('Todos los proxies fallaron, extrayendo información básica de la URL');
      return _extractBasicInfoFromUrl(url);
    } catch (e) {
      print('Error general al usar proxies: $e');
      return _extractBasicInfoFromUrl(url);
    }
  }
  
  String _extractMainContent(Document document, String url) {
    if (document.body == null) {
      return '';
    }
    
    // Intentar varias estrategias para extraer el contenido principal
    
    // Estrategia específica para Wikipedia
    if (url.contains('wikipedia.org')) {
      print('Detectada URL de Wikipedia: $url');
      
      // Obtener el título de la página
      String title = '';
      final titleElement = document.querySelector('h1#firstHeading');
      if (titleElement != null) {
        title = titleElement.text.trim();
        print('Título de Wikipedia encontrado: $title');
      }
      
      // Intentar obtener el contenido principal de Wikipedia
      final wikiContent = document.querySelector('#mw-content-text');
      if (wikiContent != null) {
        // Eliminar elementos no deseados
        wikiContent.querySelectorAll('.reference').forEach((element) => element.remove());
        wikiContent.querySelectorAll('.mw-editsection').forEach((element) => element.remove());
        wikiContent.querySelectorAll('table').forEach((element) => element.remove());
        wikiContent.querySelectorAll('.navbox').forEach((element) => element.remove());
        wikiContent.querySelectorAll('.infobox').forEach((element) => element.remove());
        
        // Extraer párrafos principales
        final paragraphs = wikiContent.querySelectorAll('p');
        if (paragraphs.isNotEmpty) {
          final mainText = paragraphs.take(8).map((p) => p.text.trim()).where((text) => text.isNotEmpty).join('\n\n');
          if (mainText.isNotEmpty) {
            // Combinar título y contenido
            return title.isNotEmpty ? '$title:\n\n$mainText' : mainText;
          }
        }
      }
    }
    
    // 1. Buscar etiquetas article o main
    final mainContent = document.querySelector('article') ?? 
                         document.querySelector('main');
    
    if (mainContent != null && mainContent.text != null) {
      return _cleanText(mainContent.text!);
    }
    
    // 2. Buscar el div con más texto (posible contenido principal)
    Element? largestTextBlock;
    int maxLength = 0;
    
    final divElements = document.querySelectorAll('div');
    for (final div in divElements) {
      if (div.text != null) {
        final text = div.text!;
        if (text.length > maxLength) {
          maxLength = text.length;
          largestTextBlock = div;
        }
      }
    }
    
    if (largestTextBlock != null && largestTextBlock.text != null) {
      return _cleanText(largestTextBlock.text!);
    }
    
    // 3. Si todo falla, usar el body completo
    final bodyText = document.body!.text;
    if (bodyText != null) {
      return _cleanText(bodyText);
    }
    
    return '';
  }
  
  String _cleanText(String text) {
    // Eliminar espacios en blanco excesivos
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ');
    
    // Eliminar caracteres no imprimibles
    cleaned = cleaned.replaceAll(RegExp(r'[\p{C}]', unicode: true), '');
    
    // Eliminar líneas vacías y espacios al inicio/final
    cleaned = cleaned.trim();
    
    // Limitar la longitud para evitar textos excesivamente largos
    if (cleaned.length > 10000) {
      cleaned = cleaned.substring(0, 10000) + '... (texto truncado)';
    }
    
    return cleaned;
  }
  
  // Método para extraer información básica de la URL cuando todo lo demás falla
  String _extractBasicInfoFromUrl(String url) {
    try {
      // Extraer el dominio y la ruta
      final uri = Uri.parse(url);
      final domain = uri.host;
      
      // Extraer el título de la página a partir de la ruta
      String title = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : domain;
      
      // Limpiar el título
      title = title.replaceAll('-', ' ').replaceAll('_', ' ');
      if (title.contains('.')) {
        title = title.substring(0, title.lastIndexOf('.'));
      }
      
      // Convertir a título capitalizado
      title = title.split(' ').map((word) => 
        word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
      ).join(' ');
      
      // Crear un texto informativo
      return 'Información sobre "$title" de $domain.\n\n'
             'Esta página web contiene información relevante sobre $title. '
             'La URL completa es: $url\n\n'
             'Nota: No se pudo extraer el contenido completo de la página debido a restricciones de seguridad del navegador. '
             'Esta es una descripción generada automáticamente basada en la URL.';
    } catch (e) {
      return 'URL: $url\n\nNo se pudo extraer información detallada de esta URL debido a restricciones del navegador.';
    }
  }
  
  // Método especial para extraer información de URLs de Wikipedia
  String _extractWikipediaInfoFromUrl(String url) {
    try {
      print('Procesando URL de Wikipedia: $url');
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      // Buscar el título de la página de Wikipedia
      String title = '';
      String language = 'es'; // Idioma por defecto
      
      // Intentar detectar el idioma del artículo
      if (uri.host.contains('.')) {
        final hostParts = uri.host.split('.');
        if (hostParts.length > 0 && hostParts[0] != 'www') {
          language = hostParts[0];
          print('Idioma detectado: $language');
        }
      }
      
      // Extraer el título del artículo
      if (pathSegments.length > 1) {
        // Buscar el segmento que contiene el título (normalmente el último)
        for (int i = pathSegments.length - 1; i >= 0; i--) {
          if (pathSegments[i].isNotEmpty && 
              !pathSegments[i].contains('index') && 
              !pathSegments[i].contains('wiki')) {
            title = pathSegments[i];
            break;
          }
        }
        
        // Si no encontramos nada, usar el último segmento
        if (title.isEmpty && pathSegments.isNotEmpty) {
          title = pathSegments.last;
        }
      }
      
      // Si aún no tenemos título, intentar extraerlo de otra manera
      if (title.isEmpty) {
        // Buscar después de /wiki/ en la URL
        final wikiIndex = url.indexOf('/wiki/');
        if (wikiIndex != -1) {
          final afterWiki = url.substring(wikiIndex + 6);
          final endIndex = afterWiki.indexOf('/');
          if (endIndex != -1) {
            title = afterWiki.substring(0, endIndex);
          } else {
            title = afterWiki;
          }
        }
      }
      
      // Limpiar y formatear el título
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
      if (title.isNotEmpty) {
        title = title.split(' ').map((word) => 
          word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
        ).join(' ');
      }
      
      print('Título extraído: "$title"');
      
      // Si es un artículo de Wikipedia, crear un resumen informativo
      if (title.isNotEmpty) {
        return 'Artículo de Wikipedia: $title\n\n'
               'Este artículo de Wikipedia ($language) contiene información detallada sobre $title. '
               'Wikipedia es una enciclopedia libre y editada colaborativamente.\n\n'
               'Los artículos de Wikipedia suelen incluir información sobre la historia, '
               'características, importancia y contexto del tema tratado.\n\n'
               'El artículo probablemente cubre los siguientes aspectos de $title:\n'
               '- Definición y conceptos básicos\n'
               '- Contexto histórico y desarrollo\n'
               '- Características principales\n'
               '- Importancia y aplicaciones\n'
               '- Referencias y fuentes adicionales\n\n'
               'Para acceder al contenido completo, visita: $url';
      }
      
      return 'Artículo de Wikipedia\n\nEste enlace apunta a un artículo de la enciclopedia Wikipedia. '
             'No se pudo extraer el título específico del artículo, pero contiene información enciclopédica sobre el tema. '
             'Debido a restricciones de seguridad del navegador, no se puede acceder directamente al contenido completo.';
    } catch (e) {
      print('Error procesando URL de Wikipedia: $e');
      // Intentar extraer algo de información incluso si hay error
      String simplifiedTitle = '';
      try {
        // Extraer la última parte de la URL como posible título
        final parts = url.split('/');
        if (parts.isNotEmpty) {
          simplifiedTitle = parts.last.replaceAll('_', ' ').replaceAll('-', ' ');
        }
      } catch (_) {}
      
      if (simplifiedTitle.isNotEmpty) {
        return 'Artículo de Wikipedia: $simplifiedTitle\n\n'
               'Este enlace apunta a un artículo de Wikipedia sobre $simplifiedTitle. '
               'No se pudo procesar completamente debido a restricciones del navegador.';
      }
      
      return 'Artículo de Wikipedia\n\nEste enlace apunta a un artículo de la enciclopedia Wikipedia. '
             'No se pudo extraer el título o contenido del artículo debido a un error: ${e.toString().substring(0, min(100, e.toString().length))}';
    }
  }
}
