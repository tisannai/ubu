/**
 * @file   inotify.c
 * @author Tero Isannainen <tero.isannainen@gmail.com>
 * @date   Thu Feb 11 14:37:00 2021
 * 
 * @brief  Inotify interface for guile.
 *
 * This library is a wrapper for C-based Inotify function API. User
 * should typically use the "(ubu inotify)" module which contains the
 * Scheme API proper for Inotify users.
 * 
 * See: "shell> man -s 7 inotify" for details about watch-types that
 *      can be used.
 *
 */

#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <linux/limits.h>
#include <sys/inotify.h>
#include <libguile.h>


/* Maximum size of one Inotify event data structure. */
#define INOTIFY_EVENT_SIZE ( sizeof( struct inotify_event ) + NAME_MAX + 1 )


/**
 * Initialize Inofity.
 * 
 * @return File descriptor.
 */
SCM scm_inotify_open( void )
{
    return scm_from_int( inotify_init1( 0 ) );
}


/**
 * Close Inotify.
 * 
 * @param fd File descriptor.
 * 
 * @return Return value of "close".
 */
SCM scm_inotify_close( SCM fd )
{
    return scm_from_int( close( scm_to_int( fd ) ) );
}


/**
 * Add watch to Inotify.
 * 
 * @param fd        Inotify file descriptor.
 * @param pathname  Pathname to watch.
 * @param mask      Event bitmask to watch for.
 * 
 * @return Watch descriptor, i.e. return value of "inotify_add_watch".
 */
SCM scm_inotify_add_watch( SCM fd, SCM pathname, SCM mask )
{
    char buf[ PATH_MAX ];
    scm_to_locale_stringbuf( pathname, buf, PATH_MAX );
    return scm_from_int( inotify_add_watch( scm_to_int( fd ), buf, scm_to_uint32( mask ) ) );
}


/**
 * Remove watch from Inotify.
 * 
 * @param fd     Inotify file descriptor.
 * @param wd     Watch descriptor.
 * 
 * @return Return value of "inotify_rm_watch".
 */
SCM scm_inotify_rm_watch( SCM fd, SCM wd )
{
    return scm_from_int( inotify_rm_watch( scm_to_int( fd ), scm_to_int( wd ) ) );
}


/**
 * Wait for event to occur for Inotify descriptor (fd).
 * 
 * @param fd    Inotify file descriptor.
 * 
 * @return Event descriptor (assoc of Inotify event C-struct, see "man -s 7 inotify").
 */
SCM scm_inotify_get_event( SCM fd )
{
    char                  inotify_ev_buf[ INOTIFY_EVENT_SIZE ];
    struct inotify_event* inotify_ev;
    int                   ret;
    SCM                   ev_desc;

    ret = read( scm_to_int( fd ), inotify_ev_buf, INOTIFY_EVENT_SIZE );
    if ( ret < 0 ) {
        scm_error_scm( scm_from_locale_symbol( "system-error" ),
                       scm_from_locale_string( "scm_inotify_get_event" ),
                       scm_from_locale_string( "inotify event read error" ),
                       SCM_EOL,
                       scm_list_1( scm_from_uint32( errno ) ) );
    }
    inotify_ev = (struct inotify_event*)inotify_ev_buf;
    ev_desc = scm_list_n(
        scm_cons( scm_from_locale_symbol( "wd" ), scm_from_int( inotify_ev->wd ) ),
        scm_cons( scm_from_locale_symbol( "mask" ), scm_from_uint32( inotify_ev->mask ) ),
        scm_cons( scm_from_locale_symbol( "cookie" ), scm_from_uint32( inotify_ev->cookie ) ),
        scm_cons( scm_from_locale_symbol( "len" ), scm_from_uint32( inotify_ev->len ) ),
        scm_cons( scm_from_locale_symbol( "name" ),
                  ( inotify_ev->len > 0 ) ? scm_from_locale_symbol( inotify_ev->name )
                                          : SCM_BOOL_F ),
        SCM_UNDEFINED );

    return ev_desc;
}


/**
 * Declare Inotify module for Guile.
 * 
 * @param dummy   It is dummy, really...
 */
void init_inotify_c_module( void* dummy )
{
    /* Inotify functions: */
    scm_c_define_gsubr( "c-inotify-open", 0, 0, 0, scm_inotify_open );
    scm_c_define_gsubr( "c-inotify-close", 1, 0, 0, scm_inotify_close );
    scm_c_define_gsubr( "c-inotify-add-watch", 3, 0, 0, scm_inotify_add_watch );
    scm_c_define_gsubr( "c-inotify-rm-watch", 2, 0, 0, scm_inotify_rm_watch );
    scm_c_define_gsubr( "c-inotify-get-event", 1, 0, 0, scm_inotify_get_event );

    /* Inotify events: */
    scm_c_define(
        "c-inotify-events",
        scm_list_n(
            scm_cons( scm_from_locale_symbol( "in-access" ), scm_from_uint32( IN_ACCESS ) ),
            scm_cons( scm_from_locale_symbol( "in-attrib" ), scm_from_uint32( IN_ATTRIB ) ),
            scm_cons( scm_from_locale_symbol( "in-close-write" ),
                      scm_from_uint32( IN_CLOSE_WRITE ) ),
            scm_cons( scm_from_locale_symbol( "in-close-nowrite" ),
                      scm_from_uint32( IN_CLOSE_NOWRITE ) ),
            scm_cons( scm_from_locale_symbol( "in-create" ), scm_from_uint32( IN_CREATE ) ),
            scm_cons( scm_from_locale_symbol( "in-delete" ), scm_from_uint32( IN_DELETE ) ),
            scm_cons( scm_from_locale_symbol( "in-delete-self" ),
                      scm_from_uint32( IN_DELETE_SELF ) ),
            scm_cons( scm_from_locale_symbol( "in-modify" ), scm_from_uint32( IN_MODIFY ) ),
            scm_cons( scm_from_locale_symbol( "in-move-self" ), scm_from_uint32( IN_MOVE_SELF ) ),
            scm_cons( scm_from_locale_symbol( "in-moved-from" ), scm_from_uint32( IN_MOVED_FROM ) ),
            scm_cons( scm_from_locale_symbol( "in-moved-to" ), scm_from_uint32( IN_MOVED_TO ) ),
            scm_cons( scm_from_locale_symbol( "in-open" ), scm_from_uint32( IN_OPEN ) ),
            SCM_UNDEFINED ) );

    scm_c_export( "c-inotify-open",
                  "c-inotify-close",
                  "c-inotify-add-watch",
                  "c-inotify-rm-watch",
                  "c-inotify-get-event",
                  "c-inotify-events",
                  NULL );
}


/**
 * Register Inotify module to Guile.
 */
void scm_init_ubu_inotify_c_module( void )
{
    scm_c_define_module( "ubu inotify c", init_inotify_c_module, NULL );
}
