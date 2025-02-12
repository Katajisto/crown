#import "GetRect";
SCALE :: 1;  // I use this during development to quickly make the window real big.

my_window: Window_Type;
window_width  : s32 = 1920*SCALE;
window_height : s32 = 1080*SCALE;

current_time: float64;
last\  _time: float64;

// Data values that we manipulate with the widgets:

scroll_value: float;
scroll_value_dragdrop_region: float;
horizontal_scroll_value: float;
vertical_scroll_value: float;

// Data values that we manipulate with the widgets:

Grocery_Info :: struct {
    name: string;
    should_get := false;
}

groceries: [..] Grocery_Info;


dropped_files: [..] string;

spells: [..] string;  // We make a radio button of which spell to cast.
current_spell := -1;

INITIAL_STRING_A :: "Lord Dimwit Flathead";
INITIAL_STRING_B :: "Flood Control Dam #3";
INITIAL_STRING_C :: "The Troll Room";

INITIAL_STRING_T :: "Golden Monkey";

// string_a, string_b, string_c are where we store the text input strings.
string_a: string;
string_b: string;
string_c: string;

string_t: string;

Damage_Resistance :: enum_flags u16 {
    PIERCING;
    SLASHING;
    CRUSHING;
    BLUNT;
    ELECTRICAL :: 0x40;
    MAGIC;
    POISON;
    ELEMENTAL;
    EMOTIONAL;
}

damage_resistance: Damage_Resistance;

THEME_NAMES : [THEME_COUNT] string : .[
    "Default",
    "Grayscale",
    "Bentonite",
    "Nimbus",
    "Blood Vampire",
    "Freddie Freeloader",
    "HIGH CONTRAST"
];

teas :: string.["Earl Gray", "Singapore Breakfast", "Bengal Spice", "Hot Cinnamon Spice", "Tie Guanyin", "Lapsang Souchong", "Royal Pu-Erh", "Chai Juice", "Snore and Peace", "Golden Monkey", "Genmaicha", "Jasmine Pearls", "Sencha", "Gyokuro", "White Claw", "Rooibos", "Alishan Oolong"];

TEXT_FIELD_1 :: #string DONE
I thence
Invoke thy aid to my adventurous song,
That with no middle flight intends to soar
Above th' Aonian mount, while it pursues
Things unattempted yet in prose or rhyme.
And chiefly thou, O Spirit, that dost prefer
Before all temples th' upright heart and pure,
Instruct me, for thou know'st; thou from the first
Wast present, and, with mighty wings outspread,
Dove-like sat'st brooding on the vast Abyss,
And mad'st it pregnant: what in me is dark
Illumine, what is low raise and support;
That, to the height of this great argument,
I may assert Eternal Providence,
And justify the ways of God to men.
DONE

slider_float_value: float = 27.02;
slider_int_value  : s32 = 3;

current_theme: s32 = xx Default_Themes.Default;
my_theme: Overall_Theme;  // This gets filled out by calling the Theme_Proc for current_theme.

picked_color: Vector3 = .{.1, .8, .6};

// For windows that move around autonomously:
subwindow_info_text:   Subwindow_Info;
subwindow_info_circle: Subwindow_Info;
subwindow_info_color_animation_editor: Subwindow_Info;
subwindows_initted := false;


// @Cleanup: Get rid of the need for begins_with_count?
begins_with_count :: (str: string, prefix: string) -> int {
    for 0..prefix.count-1 {
        // Case-insensitive.
        if it >= str.count return it;

        // @Speed: This is a pretty slow compare.
        ca := Basic.to_lower(str[it]);    // :CompilerBug
        cb := Basic.to_lower(prefix[it]);
/*
        ca := to_lower(str[it]);
        cb := to_lower(prefix[it]);
*/
        if ca != cb return it;
    }

    return prefix.count;
}

auto_complete_teas_proc :: (input: string, data: *void) -> (results: [] string, longest_match_length: int) {
    results: [..] string;

    longest_match_length := 0;
    for teas {
        count := begins_with_count(it, input);
        if count == input.count {
            array_add(*results, it);
            longest_match_length = max(longest_match_length, input.count);
        }

        longest_match_length = max(longest_match_length, count);
    }

    return results, longest_match_length;
}

auto_complete_teas := Auto_Complete.{auto_complete_teas_proc, null};

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        // Windows is very bad at thread-switching by default unless you do this. Sad.
        Windows.timeBeginPeriod(1);
    }

    my_window = create_window(window_width, window_height, "Crown");
    Simp.set_render_target(my_window);
    my_init_fonts();
    ui_init();

    string_a = copy_string(INITIAL_STRING_A);
    string_b = copy_string(INITIAL_STRING_B);
    string_c = copy_string(INITIAL_STRING_C);
    string_t = copy_string(INITIAL_STRING_T);

    // Add some groceries.

    g := array_add(*groceries);
    g.name = "Apples";

    g = array_add(*groceries);
    g.name = "Bananas";

    g = array_add(*groceries);
    g.name = "Moon Chips";

    g = array_add(*groceries);
    g.name = "Chai Juice";


    array_add(*spells, "rezrov");
    array_add(*spells, "gondar");
    array_add(*spells, "gnusto");
    array_add(*spells, "aimfiz");


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
    // 'k' is some resolution-adjusting unit of distance. Right now it is
    // 1/10 of the screen height, so, 108 pixels at 1920x1080.
    vh := window_height * .1;
    vw := window_width * .1;
    uw := max(vw, 2*vh);

    // Render the top bar.
    label_theme := my_theme.label_theme;
    label_theme.font       = my_font;
    r := get_rect(0, 9.5*vh, 2*uw, 0.5*vh);
    label(r, "Crown v0.1", *label_theme);
    r.x += 5*vw;
    r.w = uw;
    label(r, "Theme:", *label_theme);
    r.w = 2*uw;
    r.x += max(2*vw, 4*vh);
    dropdown_theme := *my_theme.dropdown_theme;
    dropdown(r, THEME_NAMES, *current_theme, dropdown_theme);


    r = get_rect(0, 0, max(2*vw, 4*vh), 9.5*vh);
    region, inside := begin_scrollable_region(r);

    NUM_BUTTONS :: 30;
    button_height := .5*vh;

    // @Incomplete: Add the scrolling offset when we have it.
    // @Incomplete: Scroll value is in pixels, what happens if the screen changes resolution?
    s := inside;
    s.y = s.y + s.h - button_height;
    s.w -= 0.1 * vw;
    s.x += 0.05 * vw;
    s.h = button_height;
    s.y += scroll_value;
    button_theme.label_theme.alignment = .Center;
    button_theme.font = null;

    for 1..NUM_BUTTONS {
        text := tprint("Button %", it);
        pressed := button(s, text, *button_theme, it);

        if  it != NUM_BUTTONS  {
            s.y -= floor(button_height * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
        }
    }

    end_scrollable_region(region, s.x + s.w, s.y, *scroll_value);
    
    draw_popups();  // This draws Subwindows as well.
    Simp.swap_buffers(my_window);
}

my_init_fonts :: () {
    if !working_directory_set {
        path := path_strip_filename(get_path_of_running_executable());
        set_working_directory(path);
        working_directory_set = true;
    }

    pixel_height := window_height / 24;
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
Basic :: #import "Basic"; // :CompilerBug  We need this to resolve to_lower for some reason?!
#import "Math";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

modify_string :: (ps: *string, new_value: string) {
    free(ps.*);
    ps.* = copy_string(new_value);
}
