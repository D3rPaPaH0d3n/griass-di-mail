/*
 * Copyright © 2020 Michael Gratton <mike@vee.net>
 *
 * This release copy is licensed under the GNU General Public License
 * (version 3 only). See the COPYING file in this distribution.
 * Release-copy modification: 2026-10-26, LGPL-2.1 section 3 election.
 * Historical LGPL origin: docs/release/GPLV3-COPY.md.
 */

/**
 * The base class for objects implementing a client plugin.
 *
 * To implement a new plugin, have it derive from this type and
 * implement any additional extension interfaces (such as {@link
 * NotificationExtension}) as required.
 */

/**
 * Errors when plugins request resources from their contexts.
 */
public errordomain Plugin.Error {

    /** Raised when access to a requested resource was denied. */
    PERMISSION_DENIED,

    /** Raised when a requested resource was not found. */
    NOT_FOUND,

    /** Raised when a requested operation could not be carried out. */
    NOT_SUPPORTED;

}
