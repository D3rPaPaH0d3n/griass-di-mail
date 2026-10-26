/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

internal class Convey.Graph.Attachment : Convey.Attachment {

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

    internal Attachment.from_part(Convey.RFC822.Part part,
                                  GLib.File file,
                                  int64 file_size) {
        Mime.ContentDisposition? disposition = part.content_disposition;
        if (disposition == null) {
            disposition = new Mime.ContentDisposition.simple(
                Convey.Mime.DispositionType.UNSPECIFIED
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
