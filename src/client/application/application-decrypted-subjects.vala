/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

/**
 * Remembers the real subjects of encrypted email, keyed by Message-ID.
 */
public class Application.DecryptedSubjects : Convey.BaseObject {


    private GLib.File file;
    private Gee.Map<string,string> subjects = new Gee.HashMap<string,string>();


    public DecryptedSubjects(GLib.File file) {
        this.file = file;
        try {
            uint8[] contents;
            file.load_contents(null, out contents, null);
            var parser = new Json.Parser();
            parser.load_from_data((string) contents);
            Json.Object root = parser.get_root().get_object();
            foreach (string id in root.get_members()) {
                this.subjects.set(id, root.get_string_member(id));
            }
        } catch (GLib.IOError.NOT_FOUND err) {
        } catch (GLib.Error err) {
            warning("Unable to load decrypted subjects: %s", err.message);
        }
    }

    public string? get(Convey.RFC822.MessageID? id) {
        return id != null ? this.subjects.get(id.value) : null;
    }

    public void set(Convey.RFC822.MessageID id, string subject) {
        if (this.subjects.get(id.value) == subject) {
            return;
        }
        this.subjects.set(id.value, subject);

        var builder = new Json.Builder();
        builder.begin_object();
        foreach (var entry in this.subjects.entries) {
            builder.set_member_name(entry.key);
            builder.add_string_value(entry.value);
        }
        builder.end_object();
        var generator = new Json.Generator();
        generator.set_root(builder.get_root());
        try {
            generator.to_file(this.file.get_path());
        } catch (GLib.Error err) {
            warning("Unable to save decrypted subjects: %s", err.message);
        }
    }

}
