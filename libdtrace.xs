#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <dtrace.h>

/* C Functions */
int
bufhandler(const dtrace_bufdata_t *bufdata, void *arg)
{
    dtrace_probedata_t     *data = bufdata->dtbda_probe;
    const dtrace_recdesc_t *rec  = bufdata->dtbda_recdesc;
    return( DTRACE_HANDLE_OK );
}

/* And now the XS code, for C functions we want to access directly from Perl */

MODULE = Devel::libdtrace              PACKAGE = Devel::libdtrace

# XS code

PROTOTYPES: ENABLED

SV *
new( const char *class )
  PREINIT:
    dtrace_hdl_t *dtp;
  CODE:
    int  err;
    /* Create a hash */
    HV* hash = newHV();

    /* Create DTrace Handle / Context */
    /* NOTE: DTRACE_VERSION comes from dtrace.h */
    /*       This was written when it was version 3 */
    if ((dtp = dtrace_open(DTRACE_VERSION, 0, &err)) == NULL)
      croak("Unable to create a DTrace handle: %s",
            dtrace_errmsg(NULL,err));

    /*
     * Set buffer size and aggregation buffer size to a reasonable
     * size of 512K (for systems with many CPUs).
     */
    (void)dtrace_setopt(dtp, "bufsize", "512k");
    (void)dtrace_setopt(dtp, "aggsize", "512k");



    /* Create a reference to the hash */
    SV* const self = newRV_noinc( (SV *)hash );

    /* bless into the proper package */
    RETVAL = sv_bless( self, gv_stashpv( class, 0 ) );
  OUTPUT: RETVAL

const char *
version(...)
  CODE:
    RETVAL = "0.0.2";
  OUTPUT: RETVAL


