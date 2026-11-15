=============================================================================
 DR. ROBOTNIK'S RING RACERS - Port para dArkOSRE en ANBERNIC R36S (v12)
=============================================================================

 QUE ES ESTO
------------
 Build nativo ARM64 (aarch64) de Ring Racers compilado para:
   * Firmware: dArkOSRE (fork de dArkOS basado en Debian 13 "Trixie")
   * Placa: R36S / RK3326 (4x Cortex-A35 @1.3GHz, GPU Mali-G31 MP2)
   * Rendimiento: renderizado por hardware OpenGL ES 2.0 nativo (sin gl4es),
     optimizado con -O3 y -mcpu=cortex-a35.

 CONTROLES ESPECIALES
--------------------
 * START (solo) -> equivale a ESC en PC: abre el menu de pausa/opciones
   en carrera y sirve para volver atras en los menus.
 * START + SELECT a la vez -> QUIT GAME: el juego se cierra al instante.
   (Funciona en menus, en carrera y en cualquier parte del juego.)
 * D-PAD -> tambien mueve el stick izquierdo: en la Odroid Go Super
   Gamepad (el pad interno del R36S) el D-pad funciona en todo lo que
   pida stick: menus, carrera y ajustes analogicos.
 * Mapeo incluido: gamecontrollerdb.txt (junto al binario) contiene el
   mapeo del pad "GO-Super Gamepad" (GUID 190000004b4800000011000000010000)
   y variantes play_joystick de clones R36XX. El juego lo carga solo.
 * Opciones en consola:
     startpause off            <- desactivar que START sea ESC
     dpadasstick off           <- desactivar D-pad como stick
     quitcombo off             <- desactivar la combinacion de salida
     quitcombo_select <num>    (por defecto 8 = SELECT)
     quitcombo_start  <num>    (por defecto 9 = START)

 INSTALACION
-----------
 1. Copia la carpeta "ringracers-r36s" a la tarjeta SD de roms/ports
    (en dArkOSRE: /roms/ports/ringracers-r36s).
 2. Copia dentro los assets del juego (los .dta/.dlr/.kart oficiales
    de Ring Racers, descargables en kartkrew.org), junto al binario.
 3. En EmulationStation, reinicia y lanza el port desde "Ports".
    Usa el script "start-ringracers.sh" como lanzador.

 CONFIGURACION RECOMENDADA PARA RENDIMIENTO
-------------------------------------------
 Este build usa un unico renderer (GLES2 nativo). El modo "Legacy GL"
 (-opengl) NO existe en este build: necesita OpenGL de escritorio + libGLU.
 La resolucion interna es fija (320x200); la GPU solo la escala a 640x480.
 Si el juego va justo: desactiva efectos de pantalla (scr_effect 0), usa
 vid_wait 0 y baja la distancia/efectos en Opciones > Video.
 Si algo falla, revisa launch.log (junto al binario).

 CONTROLES
---------
 El pad del R36S se detecta automaticamente. Si los controles no
 responden, el pad no tiene mapeo SDL2: edita start-ringracers.sh y
 descomenta la linea SDL_GAMECONTROLLERCONFIG.

 CREDITOS
--------
 * Kart Krew - Ring Racers (GPLv2)
 * Port R36S: compilado con las opciones de cmake/r36s-aarch64.toolchain.cmake
