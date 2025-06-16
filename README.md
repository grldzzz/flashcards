# Flashcards App

Una aplicación móvil de tarjetas de estudio (flashcards) desarrollada con Flutter.

## Descripción

Esta aplicación permite a los usuarios crear y estudiar tarjetas de memoria (flashcards) y preguntas de opción múltiple. Ideal para estudiantes, profesionales o cualquier persona que necesite memorizar información importante.

## Características

- **Barajas de Flashcards**: Crea y organiza múltiples barajas de tarjetas de estudio.
- **Tipos de Contenido**:
  - Tarjetas de memoria tradicionales (pregunta/respuesta)
  - Preguntas de opción múltiple
- **Sistema de Estudio**: Seguimiento del progreso y rendimiento en cada baraja.
- **Interfaz Intuitiva**: Diseño moderno con animaciones de volteo de tarjetas.
- **Almacenamiento Local**: Tus datos se guardan localmente usando Hive.

## Tecnologías Utilizadas

- **Flutter**: Framework de UI para desarrollo multiplataforma
- **Dart**: Lenguaje de programación
- **Hive**: Base de datos NoSQL ligera para almacenamiento local
- **Provider**: Gestión de estado
- **Flip Card**: Animaciones de tarjetas

## Requisitos

- Flutter SDK ^3.7.0
- Dart SDK ^3.7.0
- Dispositivo Android o iOS / Emulador

## Instalación

1. Clona este repositorio:
   ```bash
   git clone https://github.com/tuusuario/flashcards.git
   ```

2. Navega al directorio del proyecto:
   ```bash
   cd flashcards
   ```

3. Instala las dependencias:
   ```bash
   flutter pub get
   ```

4. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## Estructura del Proyecto

```
lib/
├── models/
│   ├── flashcard.dart         # Modelo de tarjeta de estudio
│   └── multiple_choice_question.dart  # Modelo de pregunta de opción múltiple
├── services/
│   └── db_service.dart        # Servicio de base de datos con Hive
├── screens/
│   ├── home_screen.dart       # Pantalla principal
│   ├── deck_screen.dart       # Visualización de baraja
│   └── study_screen.dart      # Modo de estudio
└── main.dart                  # Punto de entrada de la aplicación
```

## Uso

1. Crea una nueva baraja desde la pantalla principal
2. Añade tarjetas o preguntas a tu baraja
3. Inicia una sesión de estudio
4. Revisa tus estadísticas de aprendizaje

## Contribución

Las contribuciones son bienvenidas. Para cambios importantes, por favor abre primero un issue para discutir lo que te gustaría cambiar.

## Licencia

[MIT](https://choosealicense.com/licenses/mit/)

## Contacto

Nombre - [Tu correo electrónico](mailto:tu@email.com)

Enlace del proyecto: [https://github.com/tuusuario/flashcards](https://github.com/tuusuario/flashcards)
