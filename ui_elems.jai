get_size_units :: () -> (float, float, float) {
    x, y, width, height := get_dimensions(my_window, true);
    vh := window_height * .1;
    vw := window_width * .1;
    uw := max(vw, 2*vh);
    return vh, vw, uw;
}

draw_top_bar :: (theme: *Overall_Theme) {
    vh, vw, uw := get_size_units();

    label_theme := my_theme.label_theme;
    label_theme.font       = my_font;
    r := get_rect(0, 9.55*vh, 0.2 * uw, 0.4*vh);
    if button(r, ifx state.user.left_bar_open then "<" else ">", *my_theme.button_theme, 100) {
        state.user.left_bar_open = !state.user.left_bar_open;
    }
    r.x += 0.2 * uw;
    r.w = 3*uw;
    label(r, "Crown v0.1", *label_theme);
    r.x = 10*vw - 3*uw;
    r.w = uw;
    label(r, "Theme:", *label_theme);
    r.w = 2*uw;
    r.x += uw;
    dropdown_theme := *my_theme.dropdown_theme;
    dropdown(r, THEME_NAMES, *current_theme, dropdown_theme);
}

draw_left_bar :: (theme: *Overall_Theme) {
    button_theme := theme.button_theme;
    button_theme.font = button_font;
    button_theme.enable_variable_frame_thickness = true;
    tab_button_theme := theme.button_theme;
    tab_button_theme.enable_variable_frame_thickness = true;
    tab_button_theme.rectangle_shape.rounding_flags = Rectangle_Shape.Rounding_Flags.NORTHWEST | Rectangle_Shape.Rounding_Flags.NORTHEAST;
    selected_tab_theme := tab_button_theme;
    selected_tab_theme.surface_color = tab_button_theme.surface_color_down;
    vh, vw, uw := get_size_units();
    scrollable_region_theme := *my_theme.scrollable_region_theme;
    scrollable_region_theme.region_background.shape.roundedness = 0.01;
    // Render the top bar.
    draw_top_bar(*my_theme);

    tab_w := uw;
    r := get_rect(0, 9*vh, tab_w, 0.5*vh);
    if button(r, "Books", ifx state.user.cur_tab == Crown_Tab.Books then *selected_tab_theme else *tab_button_theme) {
        state.user.cur_tab = Crown_Tab.Books;
    }
    r.x += tab_w;
    if button(r, "Chapters", ifx state.user.cur_tab == Crown_Tab.Chapters then *selected_tab_theme else *tab_button_theme) {
        state.user.cur_tab = Crown_Tab.Chapters;
    }
    r.x += tab_w;
    if button(r, "Bookmarks", ifx state.user.cur_tab == Crown_Tab.Bookmarks then *selected_tab_theme else *tab_button_theme) {
        state.user.cur_tab = Crown_Tab.Bookmarks;
    }

    r = get_rect(0, 0, 3*uw, 9*vh);
    {
        region, inside := begin_scrollable_region(r, scrollable_region_theme);

        NUM_BUTTONS :: 30;
        button_height := .5*vh;

        // @Incomplete: Add the scrolling offset when we have it.
        // @Incomplete: Scroll value is in pixels, what happens if the screen changes resolution?
        s := inside;
        s.y = s.y + s.h - button_height;
        s.w -= 0.1 * vw;
        s.x += 0.05 * vw;
        s.h = button_height;
        s.y += scroll_value_bar;
        button_theme.label_theme.alignment = .Center;
        button_theme.font = null;

        if state.user.cur_tab == Crown_Tab.Books {
            for 0..(state.cur_bible.books.count - 1) {
                text := tprint("%", state.cur_bible.books[it].name);
                book_button_theme := my_theme.button_theme;
                if(it == state.user.cur_book) {
                    book_button_theme.surface_color = book_button_theme.surface_color_down;
                }
                pressed := button(s, text, *book_button_theme, it);
                if(pressed) {
                    if state.user.cur_book != it {
                        state.user.cur_chapter = 0;
                    }
                    state.user.cur_tab = Crown_Tab.Chapters;
                    state.user.cur_book = it;
                }

                if  it != NUM_BUTTONS  {
                    s.y -= floor(button_height * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
                }
            }
        }
        if state.user.cur_tab == Crown_Tab.Chapters {
            cur_book_ptr := *state.cur_bible.books[state.user.cur_book];
            for 0..(cur_book_ptr.chapters.count - 1) {
                text := tprint("%", cur_book_ptr.chapters[it].name);
                book_button_theme := my_theme.button_theme;
                if(it == state.user.cur_chapter) {
                    book_button_theme.surface_color = book_button_theme.surface_color_down;
                }
                pressed := button(s, text, *book_button_theme, it);
                if(pressed) {
                    state.user.cur_chapter = it;
                }

                if  it != NUM_BUTTONS  {
                    s.y -= floor(button_height * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
                }
            }
        }
        if state.user.cur_tab == Crown_Tab.Bookmarks {
            for 0..(state.user.bookmarks.count - 1) {
                cur_bookmark := *state.user.bookmarks[it];
                text := tprint("% %:%", cur_bookmark.bookName, cur_bookmark.chapter + 1, cur_bookmark.verse + 1);
                book_button_theme := my_theme.button_theme;
                if(it == state.user.cur_chapter) {
                    book_button_theme.surface_color = book_button_theme.surface_color_down;
                }
                pressed := button(s, text, *book_button_theme, it);
                if(pressed) {
                    state.user.cur_book = cur_bookmark.book;
                    state.user.cur_chapter = cur_bookmark.chapter;
                }

                if  it != NUM_BUTTONS  {
                    s.y -= floor(button_height * 1.1 + 0.5);  // Just so r.y is in the right place for end_scrollable_region().
                }
            }
        }

        end_scrollable_region(region, s.x + s.w, s.y, *scroll_value_bar);
    }
    
}
