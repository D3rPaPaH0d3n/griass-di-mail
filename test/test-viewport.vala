/* Private downstream GTK viewport regression, 2026-11-25. GPL-3.0-only. */
// Exercise the production viewport calculation with real, differently sized
// GTK rows. No accounts, messages, monitor, or application window are needed.
private void conversation_viewport_scroll() {
    var list = new Gtk.ListBox();
    for (int i = 1; i <= 3; i++) {
        var row = new Gtk.ListBoxRow();
        row.set_size_request(100, 25 * i);
        list.append(row);
    }
    list.allocate(100, 150, -1, null);
    var first = list.get_row_at_index(0);
    var middle = list.get_row_at_index(1);
    var last = list.get_row_at_index(2);
    Graphene.Rect m, l;
    assert(middle.compute_bounds(list, out m));
    assert(last.compute_bounds(list, out l));
    assert(m.get_y() > 1 && l.get_y() > m.get_y() + 1);
    var before = ConversationList.View.rows_in_viewport(list, m.get_y() - 1, m.get_y() + 1);
    var after = ConversationList.View.rows_in_viewport(list, m.get_y(), l.get_y() + 1);
    assert(before.size == 2 && before[0] == first && before[1] == middle);
    assert(after.size == 2 && after[0] == middle && after[1] == last);
    assert(ConversationList.View.rows_in_viewport(list, m.get_y(), l.get_y()).size == 1);
    assert(ConversationList.View.rows_in_viewport(list, 0, 0).is_empty);
}

int main(string[] args) {
    Gtk.init();
    Test.init(ref args);
    Test.add_func("/conversation-list/viewport-scroll", conversation_viewport_scroll);
    return Test.run();
}
