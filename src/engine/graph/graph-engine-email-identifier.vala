/*
 * Copyright 2026 Daniel Elia <d.elia@outlook.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later). See the COPYING file in this distribution.
 */

internal class Convey.Graph.EmailIdentifier : Convey.EmailIdentifier {

    private const string VARIANT_TYPE = "(y(sx))";

    public string graph_id { get; private set; }
    public int64 sort_order { get; private set; }

    public EmailIdentifier(string graph_id, int64 sort_order) {
        this.graph_id = graph_id;
        this.sort_order = sort_order;
    }

    public EmailIdentifier.from_variant(GLib.Variant serialised)
        throws Convey.EngineError.BAD_PARAMETERS {
        if (serialised.get_type_string() != VARIANT_TYPE) {
            throw new Convey.EngineError.BAD_PARAMETERS(
                "Invalid serialised id type: %s", serialised.get_type_string()
            );
        }
        GLib.Variant inner = serialised.get_child_value(1);
        this(inner.get_child_value(0).get_string(), inner.get_child_value(1).get_int64());
    }

    public override uint hash() {
        return this.graph_id.hash();
    }

    public override bool equal_to(Convey.EmailIdentifier other) {
        Convey.Graph.EmailIdentifier? graph = other as Convey.Graph.EmailIdentifier;
        return graph != null && this.graph_id == graph.graph_id;
    }

    public override int natural_sort_comparator(Convey.EmailIdentifier o) {
        Convey.Graph.EmailIdentifier? other = o as Convey.Graph.EmailIdentifier;
        if (other == null) {
            return 1;
        }
        if (this.sort_order == other.sort_order) {
            return strcmp(this.graph_id, other.graph_id);
        }
        return this.sort_order > other.sort_order ? 1 : -1;
    }

    public override GLib.Variant to_variant() {
        return new GLib.Variant.tuple(new Variant[] {
                new GLib.Variant.byte('g'),
                new GLib.Variant.tuple(new Variant[] {
                        new GLib.Variant.string(this.graph_id),
                        new GLib.Variant.int64(this.sort_order)
                    })
            });
    }

    public override string to_string() {
        return "%s(%s)".printf(this.get_type().name(), this.graph_id);
    }

}
