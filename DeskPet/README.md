# DeskPet

Mascota de escritorio para macOS: una figura colgada de su telaraña baja desde
el borde superior de la pantalla una vez por hora, te enseña una nota para que
descanses y vuelve a subir. Escrita en Swift + AppKit, sin dependencias
externas ni APIs privadas.

- macOS 13 o superior
- Sin icono en el Dock (`LSUIElement`), se controla desde la barra de menús
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

O directamente:

```bash
bash Scripts/make_app.sh release
open build/DeskPet.app
```

`swift run` a secas también compila, pero **no** uses ese modo para el día a
día: sin bundle `.app` no se aplica `LSUIElement` (aparecería en el Dock) y
`SMAppService` no puede registrar el arranque automático.

Cuando la app arranca no verás nada salvo el icono en la barra de menús
(una hormiga). Desde ahí:

| Menú | Qué hace |
|---|---|
| Próximo aviso: … | Informativo, muestra la hora del siguiente ciclo |
| Mostrar ahora | Lanza el ciclo completo inmediatamente (útil para probar) |
| Saltar próximo aviso | Se salta una sola aparición y rearma la siguiente |
| Preferencias… | Ventana de ajustes (SwiftUI) |
| Exportar plantilla de sprites… | Guarda un PNG con las medidas exactas del sprite sheet |
| Salir de DeskPet | Cierra la app |

## Cómo funciona el ciclo

Máquina de estados explícita en `PetWindowController` + `PetAnimator`:

```
.hidden ──▶ .entering ──▶ .idle ──▶ .trick ──▶ .idle ──▶ .exiting ──▶ .hidden
```

1. `.hidden`: los dos paneles están con `orderOut`, sin animaciones ni timers
   de dibujo. No hay nada flotando en pantalla.
2. `.entering` (1,5 s): el hilo se dibuja desde el borde superior y la mascota
   baja con easing y un pequeño rebote elástico al final (curva de muelle
   amortiguado muestreada en 60 puntos; el hilo se anima con los mismos
   fotogramas, así que van perfectamente sincronizados).
3. `.idle`: balanceo continuo tipo péndulo — se rota la capa contenedora sobre
   el punto de anclaje del hilo, de modo que telaraña y mascota se mueven como
   un solo cuerpo.
4. `.trick`: pirueta de 360° sobre el hilo, con los fotogramas de la fila 1 del
   sprite sheet.
5. La nota aparece con fade-in en cuanto la mascota termina de bajar y
   permanece los segundos configurados (10 por defecto).
6. `.exiting`: se funde la nota, la mascota sube por el hilo (easing de
   entrada) y la telaraña se retrae. Vuelta a `.hidden`.

Un clic sobre la mascota descarta el aviso antes de tiempo. El panel solo
intercepta el ratón cuando el cursor está justo encima del sprite; el resto del
tiempo los clics pasan a las apps de debajo.

### Cuándo aparece

- **En punto** (por defecto): 10:00, 11:00, 12:00…
- **Cada 60 min desde el arranque**: la primera aparición es una hora después
  de abrir la app.

En ambos casos se respeta la franja horaria activa (9:00–20:00 por defecto,
extremos incluidos). Si al llegar el momento la pantalla está bloqueada, el Mac
en reposo o hay una app en pantalla completa, el aviso se **pospone al
siguiente ciclo** (queda anotado en la consola con `NSLog`).

## Formato del sprite sheet

Un único PNG con transparencia, dividido en una rejilla regular de
`filas × columnas` (configurable en Preferencias → Apariencia):

```
┌────────┬────────┬────────┬────────┬────────┬────────┐
│ idle 0 │ idle 1 │ idle 2 │ idle 3 │ idle 4 │ idle 5 │  ← fila 0: colgado
├────────┼────────┼────────┼────────┼────────┼────────┤
│ trick0 │ trick1 │ trick2 │ trick3 │ trick4 │ trick5 │  ← fila 1: pirueta
└────────┴────────┴────────┴────────┴────────┴────────┘
```

Reglas:

- **Fila 0** (la de arriba del PNG) = animación de reposo colgando. Es la única
  obligatoria.
- **Fila 1** = animación de la pirueta. Si no existe, se reutiliza la fila 0.
- Las filas siguientes se ignoran.
- Todas las casillas deben medir lo mismo: el ancho del PNG debe ser divisible
  entre el número de columnas y el alto entre el número de filas.
- Casilla cuadrada recomendada (128×128 px, o 256×256 para pantallas Retina
  grandes). El sprite se escala con `resizeAspect`, así que una casilla no
  cuadrada se verá con márgenes, no deformada.
- El filtro de magnificación es `nearest`: el pixel-art se mantiene nítido.
- El hilo de la telaraña **no** se dibuja en el sprite: lo pinta la app con un
  `CAShapeLayer` y se engancha a la parte alta de la casilla.
- El personaje debe ocupar la casilla mirando hacia arriba (como si estuviera
  agarrado al hilo por encima de su cabeza), centrado horizontalmente.

## Sustituir los sprites por los tuyos

Tienes dos vías. La más cómoda:

1. Menú de la barra → **Exportar plantilla de sprites…** y guarda el PNG.
   Sale con el mismo número de filas y columnas que tengas configurado y con
   casillas de 128×128, así que te sirve de rejilla exacta.
2. Ábrelo en tu editor (Aseprite, Pixelmator, Photoshop…) y repinta cada
   casilla respetando la rejilla. Mantén el fondo transparente.
3. Preferencias → **Apariencia** → **Elegir…** y selecciona tu PNG. Ajusta
   *Columnas*, *Filas* y *Velocidad* si tu hoja no es 6×2.
4. **Mostrar ahora** desde el menú para verlo al instante. Los cambios se
   aplican sin reiniciar (la caché de sprites se invalida sola).

La otra vía, si prefieres empotrar los sprites en la app:

1. Copia tu hoja como `DeskPet/Resources/pet_sheet.png`.
2. `make app` — el script la mete en `DeskPet.app/Contents/Resources/`.
3. Deja la ruta de Preferencias vacía: la app usa el PNG del bundle
   automáticamente.

Orden de búsqueda de sprites: **ruta de Preferencias** → **`pet_sheet.png` del
bundle** → **sprites dibujados por código**. Es decir, la app arranca y anima
igual aunque no haya ningún PNG; si la ruta configurada no se puede leer, se
avisa por consola y se cae al respaldo sin romper nada.

## Preferencias

| Pestaña | Ajustes |
|---|---|
| General | Modo de programación, franja horaria activa, tiempo en pantalla, abrir al iniciar sesión |
| Mensajes | Lista editable de recordatorios (se muestran por turnos) |
| Apariencia | Tamaño de la mascota, márgenes superior/derecho, sprite sheet, columnas, filas y fps |

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
├── PetAnimator.swift          Capas, telaraña y animaciones (Core Animation)
├── SpriteSheet.swift          Troceado del PNG + caché
├── PlaceholderSprites.swift   Sprites dibujados por código (respaldo)
├── SpriteTemplateExporter.swift  Exportación de la plantilla PNG
├── ReminderController.swift   NSPanel de la nota + dibujo pixel-art
└── PreferencesView.swift      Interfaz SwiftUI de preferencias
```

Los dos paneles son `NSPanel` independientes con
`[.borderless, .nonactivatingPanel]`, `isOpaque = false`,
`backgroundColor = .clear`, `hasShadow = false`, `level = .floating` y
`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`,
así que no roban el foco ni cambian de espacio.

## Detalles y limitaciones conocidas

- **Arranque automático**: `SMAppService.mainApp` exige un bundle `.app`
  firmado. Con la firma ad-hoc del script funciona en local; si el interruptor
  de Preferencias se vuelve solo a su sitio, mira la consola — ahí queda el
  error exacto.
- **Detección de pantalla completa**: se hace con `CGWindowListCopyWindowInfo`
  buscando una ventana de nivel 0 que ocupe exactamente una pantalla. Es una
  heurística: una ventana sin bordes maximizada a mano cuenta como pantalla
  completa.
- **Multi-monitor**: la mascota aparece en la pantalla donde esté el cursor en
  ese momento. Si cambia la configuración de pantallas mientras está visible,
  se recoloca sola.
- **Consumo**: en `.hidden` no hay `CADisplayLink` ni animaciones; solo un
  `Timer` con 5 s de tolerancia. El monitor global de ratón se instala al
  aparecer y se retira al esconderse.
