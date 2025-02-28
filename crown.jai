#import "GetRect";
SCALE :: 1;  // I use this during development to quickly make the window real big.

my_window: Window_Type;
window_width  : s32 = 1920*SCALE;
window_height : s32 = 1080*SCALE;

current_time: float64;
last\  _time: float64;

// Data values that we manipulate with the widgets:

scroll_value_bar: float;
scroll_value_reader: float;
scroll_value_dragdrop_region: float;
horizontal_scroll_value: float;
vertical_scroll_value: float;

#load "ui_elems.jai";
#load "state.jai";

state : Crown_State;

THEME_NAMES : [THEME_COUNT] string : .[
    "Default",
    "Grayscale",
    "Bentonite",
    "Nimbus",
    "Blood Vampire",
    "Freddie Freeloader",
    "HIGH CONTRAST"
];

slider_float_value: float = 27.02;
slider_int_value  : s32 = 3;

current_theme: s32 = xx Default_Themes.Default;
my_theme: Overall_Theme;  // This gets filled out by calling the Theme_Proc for current_theme.

// For windows that move around autonomously:
subwindow_info_text:   Subwindow_Info;
subwindow_info_circle: Subwindow_Info;
subwindow_info_color_animation_editor: Subwindow_Info;
subwindows_initted := false;

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    success, bible := json_parse_file("./data/pyharaamattu1992.json", Bible, ignore_unknown=true);
    state.cur_bible = bible;

    config_read_success, config := json_parse_file("userdata.json", Crown_User_State, ignore_unknown=true);
    if config_read_success {
        state.user = config;
    }    
    print("Success: %\n", success);
    print("Bible size: %\n", bible.books.count);

    my_window = create_window(window_width, window_height, "Crown");
    Simp.set_render_target(my_window);
    my_init_fonts();
    ui_init();

    quit := false;
    while !quit {
        current_time = seconds_since_init();
        dt := cast(float)(current_time - last_time);
        Clamp(*dt, 0, 0.1);
        last_time = current_time;

        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);

            if it.window == my_window {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                window_width  = it.width;
                window_height = it.height;
                if should_reinit my_init_fonts();  // Resize the font for the new window size.
            }
        }

        for event: Input.events_this_frame {
            if event.type == .QUIT then quit = true;

            getrect_handle_event(event);

            if event.type == {
              case .KEYBOARD;
                if event.key_pressed && event.key_code == .ESCAPE {
                    active_widget_deactivate_all();
                }
            }
        }

        draw_one_frame(dt);

        reset_temporary_storage();
        sleep_milliseconds(10);
    }
    success = json_write_file("userdata.json", state.user);
    if !success {
        print("Failed to write out config, sad!\n");
    }
}

draw_one_frame :: (dt: float) {
    proc := default_theme_procs[current_theme];
    my_theme = proc();
    set_default_theme(my_theme);  // Just in case we don't explicitly pass themes sometimes...!
    
    bg_col := my_theme.background_color;
    Simp.clear_render_target(bg_col.x, bg_col.y, bg_col.z, 1);

    x, y, width, height := get_dimensions(my_window, true);
    ui_per_frame_update(my_window, width, height, current_time);

    button_theme := my_theme.button_theme;
    button_theme.font = button_font;
    button_theme.enable_variable_frame_thickness = true;

    vh, vw, uw := get_size_units();

    scrollable_region_theme := *my_theme.scrollable_region_theme;
    scrollable_region_theme.region_background.shape.roundedness = 0;

    draw_top_bar(*my_theme);

    left_bar_width := 3*uw;
    
    if state.user.left_bar_open {
        draw_left_bar(*my_theme);
    } else {
        left_bar_width = 0;
    }
    
    {
        r := get_rect(left_bar_width, 0, 10*vw - left_bar_width, 9.5*vh);
        region2, inside2 := begin_scrollable_region(r, scrollable_region_theme);
        s2 := inside2;
        s2.y = s2.y + s2.h - .5*vh;
        s2.w -= 0.1 * vw;
        s2.x += 0.05 * vw;
        s2.h = .5*vh;
        s2.y += scroll_value_reader;

        cur_chapter := state.cur_bible.books[state.user.cur_book].chapters[state.user.cur_chapter];
    
        verse_theme := my_theme.label_theme;
        verse_theme.font       = story_font;
        verse_theme.alignment = Text_Alignment.Left;
        for 0..(cur_chapter.verses.count - 1) {
            bookmark_w := 0.3*uw;
            total_w := s2.w;
            s2.w = bookmark_w;
            bookmark_pressed := button(s2, tprint("%:%", cur_chapter.verses[it].chapter, cur_chapter.verses[it].verse), *button_theme, it);
            if bookmark_pressed {
                array_add(*state.user.bookmarks, .{
                    state.cur_bible.abbreviation,
                    state.cur_bible.books[state.user.cur_book].name,
                    state.user.cur_book,
                    state.user.cur_chapter,
                    it
                });
            }
            s2.x += bookmark_w;
            s2.w = total_w - bookmark_w;
            verse_text := cur_chapter.verses[it].text;

            // Print a single verse:
            
            text := tprint("%", cur_chapter.verses[it].text);
            total_count := text.count;
            while total_count > 0 {
                // Let's just initially say we print 120 character lines.
                max_line_low := ifx state.user.left_bar_open then 55 else 95;
                
                if total_count > max_line_low {
                    search_space :: 20;
                    line_breakpoint := 0;
                    for 0..search_space {
                        if text.data[max_line_low - it] == 32 {
                            line_breakpoint = max_line_low - it + 1;
                        }
                    }
                    total_count -= line_breakpoint;
                    text.count = line_breakpoint;
                    label(s2, text, *verse_theme);
                    text.data += line_breakpoint;
                    s2.y -= floor(.5*vh * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
                } else {
                    text.count = total_count;
                    label(s2, text, *verse_theme);
                    total_count = 0;
                    s2.y -= floor(.5*vh * 1.5 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
                }
            }
            s2.x -= bookmark_w;
            s2.w = total_w;
        }

        end_scrollable_region(region2, s2.x + s2.w, s2.y, *scroll_value_reader);
    }

    draw_popups();  // This draws Subwindows as well.
    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    pixel_height := window_height / 29;
    my_font = Simp.get_font_at_size("data", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(my_font != null);

    pixel_height /= 2;
    button_font = Simp.get_font_at_size("data", "OpenSans-BoldItalic.ttf", pixel_height);
    assert(button_font != null);

    pixel_height = window_height / 7;
    title_font = Simp.get_font_at_size("data", "Miama.otf", pixel_height);

    pixel_height = window_height / 30;
    story_font = Simp.get_font_at_size("data", "OpenSans-BoldItalic.ttf", pixel_height);
//    title_font = Simp.get_font_at_size("data", "OpenSans-BoldItalic.ttf", pixel_height);
}

Font :: Simp.Dynamic_Font;

my_font:     *Font;
button_font: *Font;
title_font:  *Font;
story_font:  *Font;

working_directory_set := false;

Simp  :: #import "Simp";
Input :: #import "Input";

#import "Window_Creation";

#import "Basic";
#import "Jaison";
Basic :: #import "Basic"; // :CompilerBug  We need this to resolve to_lower for some reason?!
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

modify_string :: (ps: *string, new_value: string) {
    free(ps.*);
    ps.* = copy_string(new_value);
}
