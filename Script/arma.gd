extends Node3D





# --- Segue a Camera3 (e consequentemente o mouse-look) ---
# A arma continua estruturalmente filha do Player, mas sua posição/rotação
# visual é sincronizada com a Camera3 a cada frame. O offset é calculado
# uma vez no _ready para preservar a posição atual da arma em relação à câmera.
