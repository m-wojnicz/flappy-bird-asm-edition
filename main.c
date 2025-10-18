#include "raylib.h"                                                                     // thank god for raylib
#include <stdio.h>                                                                      // for file handling

//
//  global variables
//
Texture2D birdTextures[3];                                                              // array to hold the three bird animation frames
Texture2D pipeTexture;                                                                  // texture for the pipes
Texture2D backgroundTexture;                                                            // texture for the scrolling background
int highScore = 0;                                                                      // variable to hold the high score in memory

//
//  void c_load_assets()
//  called once at the start to load all PNG files from the 'assets' folder
//
void c_load_assets() {
    birdTextures[0] = LoadTexture("assets/bird_up.png");                                // load the up-flap frame
    birdTextures[1] = LoadTexture("assets/bird_mid.png");                               // load the mid-flap frame
    birdTextures[2] = LoadTexture("assets/bird_down.png");                              // load the down-flap frame
    pipeTexture = LoadTexture("assets/pipe.png");                                       // load the single pipe texture
    backgroundTexture = LoadTexture("assets/bg1.png");                                  // load the background image
}

//
//  void c_unload_assets()
//  called once at the end to free up the memory used by the textures
//
void c_unload_assets() {
    UnloadTexture(birdTextures[0]);                                                     //
    UnloadTexture(birdTextures[1]);                                                     // unload all three bird frames
    UnloadTexture(birdTextures[2]);                                                     //
    UnloadTexture(pipeTexture);                                                         // unload the pipe texture
    UnloadTexture(backgroundTexture);                                                   // unload the background texture
}

//
//  high Score File I/O
//

//
//  void c_init_high_score()
//  checks for 'highscore.sav' and loads the value into the global variable
//
void c_init_high_score() {
    FILE *saveFile = fopen("highscore.sav", "r");                                       // open the save file for reading ("r")
    if (saveFile != NULL) {                                                             // if the file exists
        fscanf(saveFile, "%d", &highScore);                                             // read the integer from it
        fclose(saveFile);                                                               // close the file
    }
}

//
//  int c_get_high_score()
//  returns the current high score, used by ASSembly to initialize its own copy
//
int c_get_high_score() {
    return highScore;                                                                   // just return the global var
}

//
//  void c_check_and_save_high_score(int score)
//  compares a new score to the high score and saves it if its a new record
//
void c_check_and_save_high_score(int score) {
    if (score > highScore) {                                                            // if the new score is greater
        highScore = score;                                                              // update the high score in memory
        FILE *saveFile = fopen("highscore.sav", "w");                                   // open the save file for writing ("w")
        if (saveFile != NULL) {                                                         // if the file can be opened
            fprintf(saveFile, "%d", highScore);                                         // write the new high score to it
            fclose(saveFile);                                                           // close the file
        }
    }
}

//
//  drawing wrappers (I love raylib)
//

void c_begin_drawing() { BeginDrawing(); }                                              // starts a drawing block
void c_end_drawing() { EndDrawing(); }                                                  // ends a drawing block
void c_clear_screen() { ClearBackground(SKYBLUE); }                                     // clears the screen to a color

//
//  void c_draw_background(float x)
//  draws the background twice, side-by-side, and stretched to fill the screen.
//
void c_draw_background(float x) {
    float screen_width = 1600.0f;                                                                   // window width
    float screen_height = 1000.0f;                                                                  // window height
    Rectangle source = { 0, 0, (float)backgroundTexture.width, (float)backgroundTexture.height };   // the whole source image
    Rectangle dest1 = { x, 0, screen_width, screen_height };                                        // destination for the first draw (stretched)
    Rectangle dest2 = { x + screen_width, 0, screen_width, screen_height };                         // destination for the second, seamless draw
    DrawTexturePro(backgroundTexture, source, dest1, (Vector2){0,0}, 0, WHITE);                     // draw the first background
    DrawTexturePro(backgroundTexture, source, dest2, (Vector2){0,0}, 0, WHITE);                     // draw the second to create the loop
}

//
//  void c_draw_bird_anim(int frame, float x, float y, float rotation, int width, int height)
//  draws the correct bird animation frame at a given position, rotation, and size.
//
void c_draw_bird_anim(int frame, float x, float y, float rotation, int width, int height) {
    if (frame < 0 || frame > 2) frame = 0;                                                                  // safety check for the frame number
    Rectangle source = { 0.0f, 0.0f, (float)birdTextures[frame].width, (float)birdTextures[frame].height }; // the source image
    Rectangle dest = { x, y, (float)width, (float)height };                                                 // the destination rectangle (with new size)
    Vector2 origin = { (float)width / 2, (float)height / 2 };                                               // the rotation origin (center of the bird)
    DrawTexturePro(birdTextures[frame], source, dest, origin, rotation, WHITE);                             // the actual draw call
}

//
//  void c_draw_pipe(int x, int y, int width)
//  uses the 9-slice method (2 slice in this case xd) to draw a pipe
//
void c_draw_pipe(int x, int y, int width) {
    int gap_half = 120;                                                                 // half the size of the gap
    float screen_height = 1000.0f;                                                      // window height
    
    // define the slices of the pipe
    float cap_height = 26.0f;                                                           // the height of the cap part of the PNG
    Rectangle cap_source = { 0, 0, (float)pipeTexture.width, cap_height };              // source for the cap
    Rectangle body_source = { 0, cap_height, (float)pipeTexture.width, 1.0f };          // a 1px high slice of the body for stretching

    // bottom pipe
    float bottom_body_y = (float)y + gap_half + cap_height;                                     // calculate where the body starts
    float bottom_body_height = screen_height - bottom_body_y;                                   // calculate how tall the body needs to be
    Rectangle bottom_body_dest = { (float)x, bottom_body_y, (float)width, bottom_body_height }; // destination for the stretched body
    DrawTexturePro(pipeTexture, body_source, bottom_body_dest, (Vector2){0,0}, 0, WHITE);       // draw the body
    Rectangle bottom_cap_dest = { (float)x, (float)y + gap_half, (float)width, cap_height };    // destination for the cap
    DrawTexturePro(pipeTexture, cap_source, bottom_cap_dest, (Vector2){0,0}, 0, WHITE);         // draw the cap on top

    // top pipe
    float top_body_height = (float)y - gap_half - cap_height;                                           // calculate how tall the top body needs to be
    Rectangle top_body_dest = { (float)x, 0, (float)width, top_body_height };                           // destination for the top body
    DrawTexturePro(pipeTexture, body_source, top_body_dest, (Vector2){0,0}, 0, WHITE);                  // draw the top body
    Rectangle cap_source_flipped = { 0, 0, (float)pipeTexture.width, -cap_height };                     // a flipped source for the top cap
    Rectangle top_cap_dest = { (float)x, (float)y - gap_half - cap_height, (float)width, cap_height };  // destination for the top cap
    DrawTexturePro(pipeTexture, cap_source_flipped, top_cap_dest, (Vector2){0,0}, 0, WHITE);            // draw the flipped cap
}

// text drawing helpers
void c_draw_text_black(const char* text, int x, int y, int size) { DrawText(text, x, y, size, BLACK); }
void c_draw_text_gray(const char* text, int x, int y, int size) { DrawText(text, x, y, size, LIGHTGRAY); }

// input wrapper
int c_is_space_pressed() { return IsKeyPressed(KEY_SPACE); }                             // returns true for one frame on press
int c_is_space_down() { return IsKeyDown(KEY_SPACE); }                                   // returns true every frame key is held
int c_is_space_released() { return IsKeyReleased(KEY_SPACE); }                           // returns true for one frame on release

// random value wrapper (helper?)
int c_get_random_value(int min, int max) { return GetRandomValue(min, max); }            // returns a random integer in a range

//
//  void main()
//  the main entry point of the program
//
extern void game_main_loop(void);                                                       // tell C this function exists in an assembly file

int main(void)
{
    InitWindow(1600, 1000, "Flappy Bird (ASSembly edition)");                           // create the window
    SetTargetFPS(60);                                                                   // lock the game to 60 FPS
    
    c_init_high_score();                                                                // load the high score from file
    c_load_assets();                                                                    // load all images

    // maino game loopo
    while (!WindowShouldClose())                                                        // loop until user closes the window
    {
        game_main_loop();                                                               // call the main assembly logic every frame
    }

    c_unload_assets();                                                                  // free up image memory
    CloseWindow();                                                                      // close the window and OpenGL context
    return 0;                                                                           // exit the program
}





