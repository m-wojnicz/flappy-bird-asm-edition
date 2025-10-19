.data
    #
    #  game state and core variables
    #
    game_state: .long 0                                             # current game state: 0 = menu, 1 = gameplay, 2 = game over

    # bird
    bird_x:         .long 300                                       # birds X position (constant/fixed)
    bird_y:         .long 500                                       # birds Y position
    bird_velocity:  .long 0                                         # birds current vertical speed
    bird_rotation:  .long 0                                         # birds current visual rotation
    anim_counter:   .long 0                                         # timer for cycling animation frames
    anim_frame:     .long 1                                         # current animation frame to draw (0, 1, or 2)
    
    # background
    background_scroll_x: .long 0                                    # the horizontal uh offset? for the scrolling background

    #
    #  constants (so that I dont get candy modifying 2000000 liens of code when I want to change something small)
    #
    gravity:                .long 1                                 # value added to velocity each frame
    flap_force:             .long -15                               # instant velocity change on flap
    pipe_speed:             .long -800                              # initial pipe speed (fixed-point: -8.00 pixels/frame)
    pipe_speed_accumulator: .long 0                                 # sub-pixel accumulator for smooth speed
    pipe_gap_half:          .long 120                               # half the height of the gap between pipes
    screen_width:           .long 1600                              # window width
    screen_height:          .long 1000                              # window height
    pipe_width:             .long 120                               # visual width of the pipes
    pipe_train_width:       .long 1650                              # total width of the 3-pipe conveyor belt
    bird_width:             .long 60                                # birds collision and drawing width
    bird_height:            .long 42                                # birds collision and drawing height

    #
    #  dynamic "variables"
    #
    # pipe properties (x, y-center, scored_flag) (OMG I love that you can use ';' in ASSembly)
    pipe1_x: .long 1600; pipe1_y: .long 500; pipe1_scored: .long 0  #
    pipe2_x: .long 2150; pipe2_y: .long 600; pipe2_scored: .long 0  #
    pipe3_x: .long 2700; pipe3_y: .long 400; pipe3_scored: .long 0  #

    # score and high score
    score:                  .long 0                                 # players current score
    high_score:             .long 0                                 # the loaded high score
    score_buffer:           .space 32                               # a memory buffer to hold the "Score: X" string
    score_format:           .asciz "Score: %d"                      # the format string for sprintf
    highscore_buffer:       .space 32                               # a memory buffer for the "High Score: X" string
    highscore_format:       .asciz "High Score: %d"                 # the format string for sprintf

    # input flag
    can_flap:       .byte 1                                         # flag to prevent holding space to fly (1 = yes, 0 = no)

    #
    #  UI text strings
    #
    title_text:     .asciz "Flappy Bird Assembly"
    play_text:      .asciz "Press SPACE to Play"
    gameover_text:  .asciz "GAME OVER"
    restart_text:   .asciz "Press SPACE to Restart"

.text
.global game_main_loop                                      # make this function visible to the C wrapper

#
# void game_main_loop()
# gets called at the start of each loop and does everything
# acts as a STATE MACHINE for the game and decides whats going on
#
game_main_loop:
    # pro
    pushq    %rbp           #
    movq     %rsp, %rbp     #

    # state machine switch
    movl    game_state(%rip), %eax                                  # load current game state
    cmpl    $0, %eax                                                # main menu?
    je      call_main_menu                                         # if so, jump to its handler function
    cmpl    $1, %eax                                                # gameplay?
    je      call_gameplay                                          # if so, jump to its handler fucntion
    cmpl    $2, %eax                                                # game over?
    je      call_game_over                                         # if so, jump to its handler function
    jmp     end_main_loop                                          # failsafe jump (i hope its not needed)

    call_main_menu:    call handle_main_menu; jmp end_main_loop   # call and exit when back
    call_gameplay:     call handle_gameplay; jmp end_main_loop    # call and exit when back
    call_game_over:    call handle_game_over; jmp end_main_loop   # call and exit when back

    end_main_loop:
    # epi
    movq	%rbp, %rsp      #
    popq     %rbp           #
    ret                     # going back to C wrapper

#
# void handle_main_menu()
# does input and drawing for the main menu screen.
#
handle_main_menu:
    # pro
    pushq    %rbp           #
    movq     %rsp, %rbp     #  

    # logic
    call    c_is_space_pressed                              # check if space was just pressed
    cmpb    $0, %al                                         # test the boolean result
    jz      draw_menu                                      # if not pressed, just draw the menu
    
    call    reset_game_state                                # if pressed, reset all game variables
    movl    $1, game_state(%rip)                            # and change state to gameplay (1)
    jmp     menu_done                                      # skip drawing the menu this frame

    draw_menu:
    # DRAWING
    call    c_begin_drawing                                 #
    movl    background_scroll_x(%rip), %eax                 # get scroll position for bg
    cvtsi2ss %eax, %xmm0                                    # convert to float for C function
    call    c_draw_background                               # draw the background
    leaq    title_text(%rip), %rdi                          # 1: text
    movl    $600, %esi                                      # 2: x
    movl    $350, %edx                                      # 3: y
    movl    $50, %ecx                                       # 4: font size
    call    c_draw_text_black                               # draw the main title
    leaq    play_text(%rip), %rdi                           # 1: text
    movl    $680, %esi                                      # 2: x
    movl    $550, %edx                                      # 3: y
    movl    $20, %ecx                                       # 4: font size
    call    c_draw_text_black                               # draw the instruction text
    call    c_end_drawing                                   # wrapper that calls EndDrawing()

    menu_done:
    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #

#
# void handle_gameplay()
# calls the main update and draw logic
#
handle_gameplay:
    # pro
    push    %rbp            #
    mov     %rsp, %rbp      #
    # logic
    call    update_game                                     # run all physics and game rules
    call    draw_game                                       # run all drawing commands
    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #

#
# void handle_game_over()
# handles logic and drawing for the game over screen
#
handle_game_over:
    # pro
    pushq    %rbp           #
    movq     %rsp, %rbp     #   
    # logic
    movl    score(%rip), %edi                               # get final score
    call    c_check_and_save_high_score                     # check if its a new high score and save
    call    c_is_space_pressed                              # check for restart spacepress
    cmpb    $0, %al                                         #
    jz      draw_gameover                                   # if not pressed, just draw
    
    movl    $0, game_state(%rip)                            # if pressed, change state back to main menu (0)
    jmp     gameover_done                                   # skip drawing this frame

    draw_gameover:
    # drawing
    call    c_begin_drawing                                 #
    movl    background_scroll_x(%rip), %eax                 # get scroll position
    cvtsi2ss %eax, %xmm0                                    # convert to float
    call    c_draw_background                               # draw the bg
    
    # draw game over
    leaq    gameover_text(%rip), %rdi                       # 1: format string
    movl    $620, %esi                                      # 2: x
    movl    $300, %edx                                      # 3: y
    movl    $60, %ecx                                       # 4: font size
    call    c_draw_text_black                               #
    
    # draw final score text
    leaq    score_buffer(%rip), %rdi                        # 1: format string
    movl    $690, %esi                                      # 2: x
    movl    $450, %edx                                      # 3: y
    movl    $30, %ecx                                       # 4: font size
    call    c_draw_text_black                               #
    
    # format and draw high score text
    leaq    highscore_buffer(%rip), %rdi                    # 1: destination buffer
    leaq    highscore_format(%rip), %rsi                    # 2: format string
    movl    high_score(%rip), %edx                          # 3: the high score value
    xor     %eax, %eax                                      # no vector regs
    call    sprintf                                         # create the string
    leaq    highscore_buffer(%rip), %rdi                    # 1: string format
    movl    $690, %esi                                      # 2: x
    movl    $500, %edx                                      # 3: y
    movl    $30, %ecx                                       # 4: font size
    call    c_draw_text_black                               # 
    
    # Draw restart text
    leaq    restart_text(%rip), %rdi                        # 1: format string
    movl    $600, %esi                                      # 2: x
    movl    $650, %edx                                      # 3: y
    movl    $30, %ecx                                       # 4: font size
    call    c_draw_text_black                               #
    
    call    c_end_drawing                                   #

    gameover_done:
    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #

#
# void update_game()
# the core logic loop for a single frame
#
update_game:
    # PROLOGUE
    pushq    %rbp            #
    movq     %rsp, %rbp      #

    # bg scroll
    movl    background_scroll_x(%rip), %eax                 # load scroll position
    subl    $1, %eax                                        # move 1 pixel left
    movl    %eax, background_scroll_x(%rip)                 # save it back
    cmpl    $-1600, %eax                                    # check if it scrolled the entire width
    jg      no_bg_reset                                    # if not, skip reset
    movl    $0, background_scroll_x(%rip)                   # if yess, reset to 0 to create the loop
    no_bg_reset:

    # birdo physics and rotata
    movl    bird_velocity(%rip), %eax                       # load velocity
    addl    gravity(%rip), %eax                             # add gravity
    movl    %eax, bird_velocity(%rip)                       # save new velocity
    movl    bird_y(%rip), %eax                              # load Y position
    addl    bird_velocity(%rip), %eax                       # add velocity to position
    movl    %eax, bird_y(%rip)                              # save new position
    movl    bird_velocity(%rip), %eax                       # for rotation, use velocity
    imull   $2, %eax                                        # multiply by 2 for a nice effect
    cmpl    $90, %eax                                       # cap the rotation at 90 degrees (pointing down)
    jle     rot_ok                                         #
    movl    $90, %eax                                       #
    rot_ok:
    movl    %eax, bird_rotation(%rip)                       # save new rotation

    # bird frames animation
    movl    anim_counter(%rip), %eax                        # load animation timer
    addl    $1, %eax                                        # increment it
    movl    %eax, anim_counter(%rip)                        #
    cmpl    $10, %eax                                       # has it reached 10 frames?
    jl      anim_done                                       # if not, skip
    movl    $0, anim_counter(%rip)                          # if so, reset timer
    movl    anim_frame(%rip), %eax                          # load current frame
    addl    $1, %eax                                        # go to next frame
    cmpl    $3, %eax                                        # have we gone past frame 2?
    jne     frame_ok                                        # if not, it's fine
    movl    $0, %eax                                        # if so, loop back to frame 0
    frame_ok:
    movl    %eax, anim_frame(%rip)                          # save the new frame
    anim_done:

    # input
    call    c_is_space_down                                 # is space held down rn
    cmpb    $0, %al                                         #
    jz      space_not_down                                  #
    movb    can_flap(%rip), %al                             # is the can_flap flag true?
    cmpb    $0, %al                                         #
    jz      space_not_down                                  #
    movl    flap_force(%rip), %eax                          # if both are true, flap
    movl    %eax, bird_velocity(%rip)                       #
    movb    $0, can_flap(%rip)                              # and disable flapping until key is released
    space_not_down:
    call    c_is_space_released                             # did the player stop pressing
    cmpb    $0, %al                                         #
    jz      input_done                                      # if not, we're so done fr
    movb    $1, can_flap(%rip)                              # if ye, re-enable flapping
    input_done:

    # pipe logic (secret fixed point movement tech for smooth scroooool)
    movl    pipe_speed_accumulator(%rip), %eax              # load the pixel remainder
    addl    pipe_speed(%rip), %eax                          # add the current speed
    movl    $100, %ecx                                      # divisor for fixed-point
    cdq                                                     # sign-extend %eax into %edx:%eax
    idivl   %ecx                                            # divide by 100
    movl    %edx, pipe_speed_accumulator(%rip)              # accumulate the new remainder
    addl    %eax, pipe1_x(%rip)                             # 
    addl    %eax, pipe2_x(%rip)                             # move pipes by the whole number result
    addl    %eax, pipe3_x(%rip)                             #

    # pipe respawns 
    movl    pipe1_x(%rip), %eax                             # load x
    addl    pipe_width(%rip), %eax                          # add width to see if it is completely gone
    cmpl    $0, %eax                                        # if it isnt
    jg      p1_ok                                           # no need to respawn
    movl    pipe1_x(%rip), %eax                             # else load x 
    addl    pipe_train_width(%rip), %eax                    # wrap around
    movl    %eax, pipe1_x(%rip)                             # store new x 
    movl    $200, %edi                                      # 1: lower bound for pipe center
    movl    $800, %esi                                      # 2: upper bound for pipe gap
    call    c_get_random_value                              # (int, int)
    movl    %eax, pipe1_y(%rip)                             # store the new random ahh gap
    movl    $0, pipe1_scored(%rip)                          # flag as not yet scored so poitns can be earned again
    p1_ok:

    movl    pipe2_x(%rip), %eax                             #
    addl    pipe_width(%rip), %eax                          #
    cmpl    $0, %eax                                        #
    jg      p2_ok                                           #
    movl    pipe2_x(%rip), %eax                             #
    addl    pipe_train_width(%rip), %eax                    # same as pipe 1 but for piep 2
    movl    %eax, pipe2_x(%rip)                             #
    movl    $200, %edi                                      #
    movl    $800, %esi                                      #
    call    c_get_random_value                              #
    movl    %eax, pipe2_y(%rip)                             #
    movl    $0, pipe2_scored(%rip)                          #
    p2_ok:

    movl    pipe3_x(%rip), %eax                             #
    addl    pipe_width(%rip), %eax                          #
    cmpl    $0, %eax                                        #
    jg      p3_ok                                           #
    movl    pipe3_x(%rip), %eax                             #
    addl    pipe_train_width(%rip), %eax                    #
    movl    %eax, pipe3_x(%rip)                             # same as pipe 1 but for pipe 3
    movl    $200, %edi                                      #
    movl    $800, %esi                                      #
    call    c_get_random_value                              #
    movl    %eax, pipe3_y(%rip)                             #
    movl    $0, pipe3_scored(%rip)                          #
    p3_ok:

    # collision and scoring
    # ground/ceiling check
    movl    bird_y(%rip), %eax                              # load y position
    addl    $21, %eax;                                      # add 21 to get top of bird
    cmpl    screen_height(%rip), %eax                       # compare to screen height
    jl      no_g                                            # if less then we havent touched za groundo
    movl    $2, game_state(%rip)                            # if geq then gg its over he knows
    no_g:
    movl    bird_y(%rip), %eax                              #
    subl    $21, %eax                                       # sub 21 to get bottom of bird
    cmpl    $0, %eax                                        #
    jg      no_c                                            #
    movl    $2, game_state(%rip)                            #
    no_c:  
    
    # pipe check (a bit messy, but it works, I think?)
    # pipe 1
    movl    pipe_gap_half(%rip), %r10d                      # %r10 caller saved all good
    movl    bird_x(%rip), %eax                              #
    addl    $30, %eax                                       # short circuiting whether the bird is horizontally within the pipe
    cmpl    pipe1_x(%rip), %eax                             # left side
    jl      no_p1                                           #
    movl    bird_x(%rip), %eax                              #
    subl    $30, %eax                                       #
    movl    pipe1_x(%rip), %ebx                             #
    addl    pipe_width(%rip), %ebx                          #
    cmpl    %ebx, %eax                                      # right side
    jg      no_p1                                           #
    movl    bird_y(%rip), %eax                              #
    subl    $21, %eax                                       # get brid top edge
    movl    pipe1_y(%rip), %ebx                             #
    subl    %r10d, %ebx                                     #
    cmpl    %ebx, %eax                                      # and see if we touching the gpipep
    jle     p1                                              #
    movl    bird_y(%rip), %eax                              #
    addl    $21, %eax                                       #
    movl    pipe1_y(%rip), %ebx                             #
    addl    %r10d, %ebx                                     #
    cmpl    %ebx, %eax                                      #
    jge     p1                                              #
    jmp     no_p1                                           #
    p1:                                                     #
    movl    $2, game_state(%rip)                            #
    no_p1:                                                  #
    # pipe 2
    movl    bird_x(%rip), %eax                              #
    addl    $30, %eax                                       #
    cmpl    pipe2_x(%rip), %eax                             #
    jl      no_p2                                           #
    movl    bird_x(%rip), %eax                              #    
    subl    $30, %eax                                       #
    movl    pipe2_x(%rip), %ebx                             #
    addl    pipe_width(%rip), %ebx                          #
    cmpl    %ebx, %eax                                      #
    jg      no_p2                                           #
    movl    bird_y(%rip), %eax                              # same as pipe 1 buit pipe 2
    subl    $21, %eax                                       #
    movl    pipe2_y(%rip), %ebx                             #
    subl    %r10d, %ebx                                     #
    cmpl    %ebx, %eax                                      #
    jle     p2                                              #
    movl    bird_y(%rip), %eax                              #
    addl    $21, %eax                                       #
    movl    pipe2_y(%rip), %ebx                             #
    addl    %r10d, %ebx                                     #
    cmpl    %ebx, %eax                                      #
    jge     p2                                              #
    jmp     no_p2                                           #
    p2:                                                     #
    movl    $2, game_state(%rip)                            #
    no_p2:                                                  #
    # pipe 3
    movl    bird_x(%rip), %eax                              #
    addl    $30, %eax                                       #
    cmpl    pipe3_x(%rip), %eax                             #
    jl      no_p3                                           #
    movl    bird_x(%rip), %eax                              #
    subl    $30, %eax                                       #
    movl    pipe3_x(%rip), %ebx                             #
    addl    pipe_width(%rip), %ebx                          #    
    cmpl    %ebx, %eax                                      #
    jg      no_p3                                           #
    movl    bird_y(%rip), %eax                              # same as pipe 1 but pipe 3
    subl    $21, %eax                                       #
    movl    pipe3_y(%rip), %ebx                             #    
    subl    %r10d, %ebx                                     #
    cmpl    %ebx, %eax                                      #
    jle     p3                                              #
    movl    bird_y(%rip), %eax                              #
    addl    $21, %eax                                       #
    movl    pipe3_y(%rip), %ebx                             #
    addl    %r10d, %ebx                                     #
    cmpl    %ebx, %eax                                      #
    jge     p3                                              #
    jmp     no_p3                                           #
    p3:                                                     #
    movl    $2, game_state(%rip)                            #
    no_p3:                                                  #
    
    # scoring check (did bird pass te pipe)
    # pipe1
    cmpl    $0, pipe1_scored(%rip)                          # load whether this pipe has already been passed (so its score counted) 
    jne     p1_skip                                         # if so we skip tis
    movl    pipe1_x(%rip), %eax                             # get pipe x position
    addl    pipe_width(%rip), %eax                          # add pipe width to it
    cmpl    bird_x(%rip), %eax                              # compare it to bird x
    jg      p1_skip                                         # if greater, means we have not passed yet, so skip
    call    increase_score_and_difficulty                   # else add 1 score and speed up the game
    movl    $1, pipe1_scored(%rip)                          # update the flag so we dont score infinitely
    p1_skip:                                                # 

    # pipe 2
    cmpl    $0, pipe2_scored(%rip)                          #
    jne     p2_skip                                         #
    movl    pipe2_x(%rip), %eax                             #
    addl    pipe_width(%rip), %eax                          #
    cmpl    bird_x(%rip), %eax                              # same as pipe 1
    jg      p2_skip                                         #      
    call    increase_score_and_difficulty                   #
    movl    $1, pipe2_scored(%rip)                          #
    p2_skip:                                                #

    # pipe 3
    cmpl    $0, pipe3_scored(%rip)                          #
    jne     p3_skip                                         #
    movl    pipe3_x(%rip), %eax                             #
    addl    pipe_width(%rip), %eax                          #
    cmpl    bird_x(%rip), %eax                              # same as pipe 1\
    jg      p3_skip                                         #
    call    increase_score_and_difficulty                   #
    movl    $1, pipe3_scored(%rip)                          #                 
    p3_skip:                                                #
    
    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #

#
# void draw_game()
# handles all drawing calls during gameplay.
#
draw_game:
    # pro
    pushq   %rbp            #
    movq    %rsp, %rbp      #  

    # drawing
    call    c_begin_drawing                                 # void
    movl    background_scroll_x(%rip), %eax                 # x offset of the scroll
    cvtsi2ss %eax, %xmm0                                    # 1f: x offset
    call    c_draw_background                               # (float)
    movl    pipe1_x(%rip), %edi                             # 1: x
    movl    pipe1_y(%rip), %esi                             # 2: y
    movl    pipe_width(%rip), %edx                          # 3: width
    call    c_draw_pipe                                     # (int, int, int)
    movl    pipe2_x(%rip), %edi                             # 1: x
    movl    pipe2_y(%rip), %esi                             # 2: y
    movl    pipe_width(%rip), %edx                          # 3: width
    call    c_draw_pipe                                     # (int, int, int)
    movl    pipe3_x(%rip), %edi                             # 1: x 
    movl    pipe3_y(%rip), %esi                             # 2: y
    movl    pipe_width(%rip), %edx                          # 3: width
    call    c_draw_pipe                                     # (int, int int)
    movl    bird_x(%rip), %eax                              # 1f: x
    cvtsi2ss %eax, %xmm0                                    # 1f: x needs to be float
    movl    bird_y(%rip), %eax                              # 2f: y
    cvtsi2ss %eax, %xmm1                                    # 2f: y (float)
    movl    bird_rotation(%rip), %eax                       # 3f: rotation
    cvtsi2ss %eax, %xmm2                                    # 3f: rotation (float)
    movl    anim_frame(%rip), %edi                          # 1i: frame
    movl    bird_width(%rip), %esi                          # 2i: width
    movl    bird_height(%rip), %edx                         # 3i: height
    call    c_draw_bird_anim                                # (float, float, float, int, int, int)
    leaq    score_buffer(%rip), %rdi                        # 1: pointer to score buffer
    leaq    score_format(%rip), %rsi                        # 2: pointer to score format string
    movl    score(%rip), %edx                               # 3: score 
    xor     %eax, %eax                                      # 4: no vector arguments
    call    sprintf                                         # format the string (int*, char*, int)
    leaq    score_buffer(%rip), %rdi                        # 1: format string
    movl    $20, %esi                                       # 2: x
    movl    $20, %edx                                       # 3: y
    movl    $40, %ecx                                       # 4: font size
    call    c_draw_text_black                               # (char*, int, int, int)
    call    c_end_drawing                                   # void

    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #

#
# void reset_game_state()
# resets all game variables to their initial state.
#
reset_game_state:
    # pro
    pushq    %rbp           #
    movq     %rsp, %rbp     #

    # logic
    call    c_get_high_score                                #
    movl    %eax, high_score(%rip)                          #
    movl    $300, bird_x(%rip)                              #
    movl    $500, bird_y(%rip)                              #
    movl    $0, bird_velocity(%rip)                         #
    movl    $0, bird_rotation(%rip)                         #
    movl    $1, anim_frame(%rip)                            #
    movl    $0, anim_counter(%rip)                          #
    movl    $1600, pipe1_x(%rip)                            #
    movl    $500, pipe1_y(%rip)                             #
    movl    $0, pipe1_scored(%rip)                          # redeclaring .data stuff, no need to comment here ;D
    movl    $2150, pipe2_x(%rip)                            #
    movl    $600, pipe2_y(%rip)                             #
    movl    $0, pipe2_scored(%rip)                          #
    movl    $2700, pipe3_x(%rip)                            #
    movl    $400, pipe3_y(%rip)                             #
    movl    $0, pipe3_scored(%rip)                          #
    movl    $0, score(%rip)                                 #
    movb    $1, can_flap(%rip)                              #
    movl    $-800, pipe_speed(%rip)                         #
    movl    $0, pipe_speed_accumulator(%rip)                #
    movl    $0, background_scroll_x(%rip)                   #

    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #

#
# void increase_score_and_difficulty()
# increments score and makes the game faster.
#
increase_score_and_difficulty:
    # pro
    push    %rbp            #
    mov     %rsp, %rbp      #

    # logic
    movl    score(%rip), %eax                               #
    addl    $1, %eax                                        # ++score
    movl    %eax, score(%rip)                               #
    movl    pipe_speed(%rip), %eax                          #S
    subl    $5, %eax                                        # pipe_speed += 5
    movl    %eax, pipe_speed(%rip)                          #

    # epi
    movq	%rbp, %rsp      #
	popq	%rbp            # 
    ret                     #
