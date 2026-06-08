# MiCompra 🛒

App Android (Flutter) para **organizar la despensa de casa, los catálogos de
precios de tus supermercados y las listas de la compra**, con el objetivo de
ahorrar dinero y saber **dónde te conviene comprar**.

Todo funciona **sin conexión**: los datos se guardan localmente en el móvil
(SQLite). Puedes hacer una copia de seguridad y pasarla a otro dispositivo.

---

## Funcionalidades

### 🏠 Despensa
- Inventario de lo que tienes en casa (cantidad, unidad, foto, notas).
- Fecha de caducidad con **semáforo**: 🔴 caducado · 🟠 caduca pronto (≤3 días) · 🟢 ok.
- **Alertas de caducidad** al abrir la app.
- Búsqueda, filtros y ordenado (por caducidad, nombre o recientes).

### 🏪 Supermercados
- Un catálogo de productos por tienda (Lidl, Mercadona, Dia…).
- Cada producto: **foto, marca, categoría, precio, unidad**.
- **Escáner de código de barras** (cámara) para añadir más rápido.
- **Precio normalizado** por kg / L para comparar de verdad.
- **Historial de precios**: se guarda cada vez que actualizas un precio.

### 🛒 Listas de la compra
- **Buscador** de productos por nombre o filtrando por supermercado.
- Etiqueta **"MÁS BARATO"** cuando un producto está en varias tiendas.
- Cantidad y **descuento por producto** (ej.: 15 % → se aplica al total).
- **Total en tiempo real** y barra de **presupuesto**.
- Agrupación por tienda con subtotales.
- Al **completar** una lista, su total se suma al gasto del mes.

### 💰 Comparador de cesta (ahorro)
- Coge una lista y calcula **cuánto te cuesta en cada supermercado**.
- Te dice **dónde sale más barata la cesta completa** y cuánto ahorras.
- **Mejor combinación**: comprando cada producto donde está más barato.
- Muestra qué tienda cubre qué productos.

### 📊 Inicio y presupuesto
- Gasto del mes, listas activas, nº de productos, alertas de caducidad.

### 💾 Copia de seguridad portable
- **Exportar** genera un `.zip` con la base de datos **y las fotos**.
- **Importar** restaura ese `.zip` en otro móvil con la app instalada.

---

## Cómo obtener el APK

### Opción A — Sin instalar nada (GitHub Actions) ✅ recomendado
Cada vez que se sube código, GitHub compila el APK automáticamente:

1. Ve a la pestaña **Actions** del repositorio en GitHub.
2. Abre la última ejecución del workflow **Build APK**.
3. Descarga el artefacto **`micompra-apk`** (contiene `app-release.apk`).
4. Pásalo al móvil e instálalo (activa "instalar apps de orígenes
   desconocidos" si te lo pide).

También puedes lanzarlo a mano: Actions → **Build APK** → **Run workflow**.

### Opción B — Compilar en tu ordenador
Requiere [Flutter](https://docs.flutter.dev/get-started/install) instalado.

```bash
flutter pub get
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

O usa el script incluido:

```bash
./build.sh
```

---

## Estructura del proyecto

```
lib/
├── models/        # Modelos de datos (Producto, Despensa, Lista, etc.)
├── database/      # Acceso a SQLite
├── providers/     # Estado de la app (Provider)
├── screens/       # Pantallas (inicio, despensa, tiendas, compra, ajustes)
├── widgets/       # Componentes reutilizables
└── utils/         # Constantes, notificaciones, copias de seguridad
```

## Tecnología
Flutter · SQLite (`sqflite`) · Provider · `mobile_scanner` · `image_picker` ·
`flutter_local_notifications` · `share_plus` · `file_picker` · `archive` · `intl`.
