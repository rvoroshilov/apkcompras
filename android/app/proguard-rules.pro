# ML Kit text recognition: solo usamos el modelo latino para leer tickets.
# El plugin google_mlkit_text_recognition referencia también los modelos de
# chino, japonés, coreano y devanagari, que NO incluimos. R8 avisa de que esas
# clases faltan; le indicamos que las ignore.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Conserva las clases del reconocedor de texto que sí usamos.
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
