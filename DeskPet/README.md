# DeskPet

Mascota de escritorio para macOS: una figura colgada de su telaraña baja desde
el borde superior de la pantalla una vez por hora, te enseña una nota para que
descanses y vuelve a subir. Escrita en Swift + AppKit, sin dependencias
externas ni APIs privadas.

- macOS 13 o superior
- Sin icono en el Dock (`LSUIElement`), se controla desde la barra de menús
- **Una sola ilustración**, animada con transformaciones de capa: nada de
  sprite sheets ni fotogramas, así que se ve nítida en Retina a cualquier tamaño
- Mientras no toca aparecer no hay ni una sola animación viva: solo el
  temporizador del próximo aviso

## Compilar y ejecutar

Necesitas las herramientas de línea de comandos de Xcode (`xcode-select --install`).

```bash
cd DeskPet
make app      # compila y monta build/DeskPet.app
make run      # lo anterior + abre la app
make install  # la copia a /Applications
```

`swift run` a secas también compila, pero **no** uses ese modo para el día a
día: sin bundle `.app` no se aplica `LSUIElement` (aparecería en el Dock) y
`SMAppService` no puede registrar el arranque automático.

Cuando la app arranca no verás nada salvo el icono en la barra de menús. Desde
ahí:

| Menú | Qué hace |
|---|---|
| Próximo aviso: … | Informativo, muestra la hora del siguiente ciclo |
| Mostrar ahora | Lanza el ciclo completo inmediatamente (útil para probar) |
| Saltar próximo aviso | Se salta una sola aparición y rearma la siguiente |
| Preferencias… | Ventana de ajustes (SwiftUI) |
| Salir de DeskPet | Cierra la app |

## Formato del arte

Un único fichero con transparencia. Recomendado en este orden:

1. **PDF vectorial** — escala sin pérdida a cualquier altura y a cualquier
   densidad de pantalla. Es lo mejor con diferencia.
2. **PNG grande** — al menos el doble de la altura configurada (para 220 pt,
   exporta 440 px de alto o más).
3. SVG, TIFF, HEIC, JPG — se intentan cargar, pero el soporte de SVG depende
   de la versión de macOS; si falla verás la silueta de respaldo y un aviso en
   la consola.

Reglas del dibujo:

- El personaje debe estar **colgando, con las manos agarrando el hilo en la
  parte superior de la imagen**, y centrado horizontalmente.
- Fondo transparente y sin recortes: el lienzo se usa entero para calcular el
  punto de anclaje.
- **No dibujes el hilo**: lo pinta la app con un `CAShapeLayer` y lo engancha
  exactamente al punto de anclaje.
- Opcionalmente, una segunda imagen con la **pose recogida** (cuerpo encogido)
  para la pirueta. Debe usar el mismo lienzo y el mismo encuadre que la
  principal, para que el crossfade no dé un salto. Si no la pones, se usa la
  normal para todo.

### Cómo ponerlo

Preferencias → **Apariencia** → **Elegir…**, tanto para la pose normal como
para la recogida. Se aplica al instante, sin recompilar.

Si prefieres empotrar el arte en la app, copia los ficheros como
`DeskPet/Resources/pet.pdf` y `DeskPet/Resources/pet_trick.pdf` (también valen
`.png`, `.svg` o `.tiff`) y ejecuta `make app`: el script los mete en el
bundle. Orden de búsqueda: **ruta de Preferencias** → **imagen del bundle** →
**silueta genérica dibujada por código**. La app arranca y anima igual aunque
no haya ningún fichero.

## Ajustar el punto de anclaje

El punto de anclaje es **dónde agarran las manos el hilo**. Sobre él pivota
todo: el balanceo, la pirueta y el enganche de la telaraña.

Se expresa en coordenadas unitarias de la imagen:

```
(0,0 · 1,0) ────────────── (1,0 · 1,0)   ← borde superior
     │                          │
     │      (0,5 · 1,0)         │        ← por defecto: centro arriba
     │      es el defecto       │
     │                          │
(0,0 · 0,0) ────────────── (1,0 · 0,0)   ← borde inferior
```

En Preferencias → Apariencia hay dos sliders (X e Y) y una **vista previa en
vivo**: tu ilustración con una cruz roja sobre el punto elegido. Muévelos hasta
que la cruz caiga justo entre las manos del personaje y ya está.

- **X** = 0 borde izquierdo, 1 borde derecho.
- **Y** = 1 borde superior, 0 borde inferior (igual que en Core Animation).
- El botón *Centro arriba* vuelve al valor por defecto (0,50 · 1,00).

Si tu dibujo tiene aire por encima de las manos (por ejemplo, un trozo de hilo
ya dibujado), baja la Y hasta la altura real de las manos: verás que la
telaraña se acorta y el giro deja de parecer descentrado.

## Cómo funciona el ciclo

Máquina de estados explícita en `PetWindowController` + `PetAnimator`:

```
.hidden ──▶ .entering ──▶ .idle ──▶ .trick ──▶ .idle ──▶ .exiting ──▶ .hidden
```

1. `.hidden`: los dos paneles están con `orderOut`, sin animaciones ni timers
   de dibujo.
2. `.entering` (1,5 s): la capa baja con una curva de muelle amortiguado
   (rebote elástico al final) mientras el hilo se alarga con `strokeEnd` de 0 a
   1. Los valores de `strokeEnd` salen de las mismas muestras que la posición,
   así que la punta del hilo está pegada a las manos incluso durante el rebote.
3. `.idle`: rotación en Z oscilando entre −6° y +6° (configurable), 2,5 s,
   `easeInEaseOut`, `autoreverses`, infinita, con un desfase aleatorio al
   arrancar para que no parezca un metrónomo. El hilo se curva en fase con el
   giro: se anima su `path` entre dos curvas cuadráticas con el punto de
   control desplazado a un lado y a otro.
4. `.trick`: giro completo de 360° sobre el punto de anclaje (1,2 s,
   `easeInEaseOut`) más un `scale` de 0,92 a mitad de giro. La rotación es
   **aditiva**, así que se suma al balanceo en vez de sustituirlo y no hay
   saltos ni al empezar ni al acabar. Si hay pose recogida, se hace crossfade a
   ella durante el giro.
5. `.exiting`: se funde la nota, el personaje sube (easing de entrada), se
   endereza y el hilo se retrae con `strokeEnd` de 1 a 0.

Un clic sobre la mascota descarta el aviso antes de tiempo. El panel solo
intercepta el ratón cuando el cursor está justo encima del dibujo.

### Cuándo aparece

- **En punto** (por defecto): 10:00, 11:00, 12:00…
- **Cada 60 min desde el arranque**: la primera aparición es una hora después
  de abrir la app.

En ambos casos se respeta la franja horaria activa (9:00–20:00 por defecto,
extremos incluidos). Si al llegar el momento la pantalla está bloqueada, el Mac
en reposo o hay una app en pantalla completa, el aviso se **pospone al
siguiente ciclo**.

## Preferencias

| Pestaña | Ajustes |
|---|---|
| General | Modo de programación, franja horaria activa, tiempo en pantalla, abrir al iniciar sesión |
| Mensajes | Lista editable de recordatorios (se muestran por turnos) |
| Apariencia | Ilustración normal y de pirueta, punto de anclaje con vista previa, altura, amplitud del balanceo, márgenes |

Todo se guarda en `UserDefaults` (dominio `com.alejandro.DeskPet`). Para volver
de cero:

```bash
defaults delete com.alejandro.DeskPet
```

## Estructura del código

```
Sources/DeskPet/
├── main.swift                 Punto de entrada (NSApplication accesoria)
├── AppDelegate.swift          Barra de menús y orquestación del ciclo
├── Preferences.swift          Ajustes persistidos (ObservableObject)
├── ScheduleController.swift   Cálculo de la próxima aparición y temporizador
├── SystemStateMonitor.swift   Bloqueo de pantalla, reposo y pantalla completa
├── PetWindowController.swift  NSPanel de la mascota y máquina de estados
├── PetAnimator.swift          Capas, telaraña y transformaciones
├── PetArtwork.swift           Carga y rasterizado del arte + silueta de respaldo
├── ReminderController.swift   NSPanel de la nota + dibujo pixel-art
└── PreferencesView.swift      Interfaz SwiftUI de preferencias
```

## Detalles y limitaciones conocidas

- **Nitidez en Retina**: la imagen se rasteriza a `altura × backingScaleFactor`
  de la pantalla donde va a aparecer, y el layer lleva ese mismo
  `contentsScale`. Al mover la app a un monitor con otra densidad se vuelve a
  rasterizar sola.
- **Tamaño de la ventana**: el panel transparente es bastante más grande que el
  dibujo porque tiene que dar cabida al círculo que barre la pirueta (radio =
  distancia del anclaje a la esquina más lejana). Por eso los márgenes
  superior y derecho se miden contra **el dibujo**, no contra el borde de la
  ventana.
- **Sentido de la curva del hilo**: el hilo se curva hacia el mismo lado al que
  se va el cuerpo. Si con tu arte prefieres el efecto contrario, invierte el
  signo de `bow` en `PetAnimator.startIdleSway()`.
- **El hilo arranca bajo la barra de menús**, no en el borde físico de la
  pantalla (se usa `visibleFrame`). Para el borde absoluto, cambia
  `screen.visibleFrame` por `screen.frame` en `PetWindowController.layout`.
- **Arranque automático**: `SMAppService.mainApp` exige un bundle `.app`
  firmado. Con la firma ad-hoc del script funciona en local.
- **Detección de pantalla completa**: heurística con
  `CGWindowListCopyWindowInfo` (ventana de nivel 0 que ocupa exactamente una
  pantalla).
- **Multi-monitor**: aparece en la pantalla donde esté el cursor.
