/*
 * Copyright (c) 2018 Oliver Giles <ohw.giles@gmail.com>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only).  See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

[CCode (cheader_filename = "ytnef.h")]
namespace Ytnef {
	[CCode (cname ="variableLength", has_type_id = false)]
	public struct VariableLength {
		[CCode (array_length_cname = "size")]
		uint8[] data;
	}

	[CCode (cname = "MAPI_UNDEFINED")]
	public VariableLength* MAPI_UNDEFINED;

	[CCode (cname = "int", cprefix = "PT_", has_type_id = false)]
	public enum PropType {
		STRING8
	}

	[CCode (cname = "int", cprefix = "PR_", has_type_id = false)]
	public enum PropID {
		DISPLAY_NAME,
		ATTACH_LONG_FILENAME
	}

	[CCode (cname = "PROP_TAG")]
	public static int PROP_TAG(PropType type, PropID id);

	[CCode (cname = "MAPIProps", has_type_id = false)]
	public struct MAPIProps {
	}

	[CCode (cname = "Attachment", has_type_id = false)]
	public struct Attachment {
		VariableLength Title;
		VariableLength FileData;
		MAPIProps MAPI;
		Attachment? next;
	}

	[CCode (cname = "TNEFStruct", destroy_function="TNEFFree", has_type_id = false)]
	public struct TNEFStruct {
		[CCode (cname = "TNEFInitialize")]
		public TNEFStruct();
		Attachment starting_attach;
	}

	[CCode (cname = "TNEFParseMemory", has_type_id = false)]
	public static int ParseMemory(uint8[] data, ref TNEFStruct tnef);

	[CCode (cname = "MAPIFindProperty")]
	public static unowned VariableLength* MAPIFindProperty(MAPIProps MAPI, uint tag);
}

