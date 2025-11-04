# RehabTech (ExoRehab AI) – Prototipo móvil de detección de ejercicio

Este repositorio contiene un **prototipo mínimo funcional (MVP)** para la
plataforma **RehabTech (ExoRehab AI)**.  La aplicación móvil utiliza la
cámara del dispositivo y la API de **detección de postura de ML Kit (basada
en MediaPipe)** para detectar movimientos corporales, visualizar el
esqueleto sobre la imagen y contar repeticiones de un ejercicio básico como
una sentadilla.  Aunque se trata de un prototipo, la estructura del código
facilita añadir nuevas pantallas, ejercicios o análisis de rendimiento en
futuras versiones.

## Características

- Pantalla de inicio simple con un botón para comenzar el ejercicio.
- Activación de la cámara (trasera por defecto, con opción de cambiar a la
  cámara frontal).  El feed se muestra en tiempo real con el esqueleto
  superpuesto.
- Detección de postura mediante **google_mlkit_pose_detection**, un plugin
  que expone las capacidades de MediaPipe a Flutter.  Se calculan las
  posiciones de 33 puntos clave del cuerpo y se dibujan líneas entre
  ellos para formar el esqueleto.
- Cálculo en tiempo real del ángulo de una articulación (rodilla izquierda
  por defecto) mediante la fórmula recomendada por Google【599519055646367†L376-L407】.
  Cuando el ángulo baja por debajo de un umbral (p. ej. 90°) se considera
  que el usuario está en posición *abajo* y cuando vuelve a superar un
  segundo umbral (p. ej. 160°) se cuenta una repetición.
- Conteo automático de repeticiones con retroalimentación textual
  (“Reps: N – Angle: XX.X°”) en pantalla.  Al finalizar la sesión el
  usuario puede detener la captura y visualizar un resumen con el número
  total de repeticiones.

## Estructura del proyecto

```
exorehab_mvp/
├── lib/
│   ├── main.dart            # Punto de entrada de la aplicación y rutas
│   ├── screens/
│   │   ├── home_screen.dart     # Pantalla de inicio
│   │   ├── exercise_screen.dart # Captura de cámara, detección y conteo
│   │   └── result_screen.dart   # Resumen del ejercicio
│   ├── services/
│   │   └── pose_utils.dart      # Utilidades para ángulos y conteo de repeticiones
│   └── widgets/
│       └── pose_painter.dart    # Pintor personalizado para dibujar el esqueleto
├── pubspec.yaml            # Dependencias y configuración de Flutter
└── README.md               # Este documento
```

## Instalación y ejecución

> **Requisitos previos**
>
> - [Flutter 3.x](https://docs.flutter.dev/get-started/install) instalado
>   correctamente (incluye el SDK de Dart).
> - Un dispositivo Android o iOS o un emulador con cámara.
> - Permisos de cámara concedidos al ejecutar la aplicación.

1. **Clonar el repositorio** en su equipo de desarrollo y navegar a la
   carpeta del proyecto:

   ```bash
   git clone <repositorio> && cd exorehab_mvp
   ```

2. **Obtener las dependencias** de Flutter descritas en
   `pubspec.yaml`:

   ```bash
   flutter pub get
   ```

3. **Conectar un dispositivo Android** (o iniciar un emulador) y ejecutar
   la aplicación:

   ```bash
   flutter run
   ```

   Flutter detectará el dispositivo conectado y compilará el APK/IPA
   correspondiente.  Si desea ejecutar en iOS, asegúrese de tener un
   entorno macOS con Xcode configurado.

### Permisos

Para poder acceder a la cámara, la app requiere añadir permisos en los
manifiestos de cada plataforma:

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
```

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>Esta aplicación necesita acceso a la cámara para detectar la postura.</string>
```

Flutter genera estos archivos al crear el proyecto, pero debe editarse
manualmente si empaqueta la aplicación.  En un prototipo ejecutado con
`flutter run` los permisos suelen solicitarse automáticamente.

## Cómo funciona el cálculo del ángulo

El algoritmo de cálculo de ángulos sigue la recomendación oficial de
Google para ML Kit【599519055646367†L376-L407】.  Dados tres puntos (A, B, C),
correspondientes a *primera articulación*, *articulación central* y *última
articulación*, el ángulo en `B` se calcula como la diferencia de las
direcciones de los vectores `(C – B)` y `(A – B)`, usando `atan2` para
obtener la dirección en radianes y luego convirtiendo a grados.  El
resultado se limita al rango [0, 180] para que siempre sea el ángulo
agudo:

```dart
final radians = atan2(c.y - b.y, c.x - b.x) - atan2(a.y - b.y, a.x - b.x);
double degrees = radians * 180.0 / pi;
degrees = degrees.abs();
if (degrees > 180.0) {
  degrees = 360.0 - degrees;
}
```

En este prototipo la articulación central es la **rodilla izquierda**.  La
aplicación considera que el usuario está en posición *abajo* cuando el
ángulo de la rodilla cae por debajo de 90 ° y que ha regresado a la
posición inicial *arriba* cuando el ángulo supera los 160 °.  Cada vez que
ocurre una transición de *abajo* a *arriba* se incrementa el contador de
repeticiones.  Puede ajustar los umbrales o cambiar la articulación en el
archivo `lib/services/pose_utils.dart` para medir flexiones de brazo,
curl de bíceps u otros ejercicios.

## Ampliaciones futuras

Este MVP constituye la base visual y técnica para un asistente de
rehabilitación más completo.  Algunas ideas de mejora incluyen:

- Implementar diferentes ejercicios y permitir que el usuario los
  seleccione.
- Ajustar automáticamente los umbrales de ángulos según la persona o el
  tipo de movimiento.
- Analizar la calidad de cada repetición (velocidad, profundidad, simetría).
- Añadir retroalimentación sonora o vibratoria.
- Sincronizar los resultados con un servidor **Flask** o una base de datos
  remota.
- Crear una interfaz de asistente virtual que guíe y motive al paciente.

## Licencia

Este proyecto se distribuye bajo la licencia MIT y se basa en el plugin
**google_mlkit_pose_detection** y en la documentación oficial de ML Kit.
