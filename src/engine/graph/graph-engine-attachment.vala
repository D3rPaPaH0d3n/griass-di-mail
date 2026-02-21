/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Geary.Graph.Attachment : Geary.Attachment {

    internal Attachment(Mime.ContentType content_type,
                        string? content_id,
                        string? content_description,
                        Mime.ContentDisposition content_disposition,
                        string? content_filename,
                        GLib.File file,
                        int64 file_size) {
        base(content_type, content_id, content_description, content_disposition, content_filename);
        set_file_info(file, file_size);
    }

    internal Attachment.from_part(Geary.RFC822.Part part,
                                  GLib.File file,
                                  int64 file_size) {
        Mime.ContentDisposition? disposition = part.content_disposition;
        if (disposition == null) {
            disposition = new Mime.ContentDisposition.simple(
                Geary.Mime.DispositionType.UNSPECIFIED
            );
        }
        this(
            part.content_type,
            part.content_id,
            part.content_description,
            (Mime.ContentDisposition) disposition,
            part.get_clean_filename(),
            file,
            file_size
        );
    }

}
