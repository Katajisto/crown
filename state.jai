Bible :: struct {
    translation: string;
    abbreviation: string;
    description: string;
    lang: string;
    language: string;
    direction: string;
    encoding: string;
    books: [..] Bible_Book;
}

Bible_Book :: struct {
    nr: u32;
    name: string;
    chapters: [..] Bible_Chapter;
}

Bible_Chapter :: struct {
    chapter: u32;
    name: string;
    verses: [..] Bible_Verse;
}

Bible_Verse :: struct {
    chapter: u32;
    verse: u32;
    name: string;
    text: string;
}

Bookmark :: struct {
    bible: string;
    bookName: string;
    book: int;
    chapter: int;
    verse: int;
}

Crown_Tab :: enum {
    Books;
    Chapters;
    Bookmarks;
    Search;
}

Crown_User_State :: struct {
    cur_book: int = 0;
    cur_chapter: int = 0;
    left_bar_open: bool = true;
    cur_tab: Crown_Tab = Crown_Tab.Books;
    bookmarks: [..] Bookmark;
}

Crown_State :: struct {
    cur_bible: Bible;
    user: Crown_User_State;
}
