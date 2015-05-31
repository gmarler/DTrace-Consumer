#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <dtrace.h>

/* Context */
typedef struct {
  dtrace_hdl_t  *dtc_handle;
  /* dtc_templ ??? */
  /* dtc_args  ??? */
  /* dtc_callback  */
  /* dtc_error     */
  /* dtc_ranges    */
  dtrace_aggvarid_t dtc_ranges_varid;
} CTX;

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
    CTX* ctx = (CTX *)malloc( sizeof(CTX) );
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

    ctx->dtc_handle = dtp;

    /*
     * Set buffer size and aggregation buffer size to a reasonable
     * size of 512K (for systems with many CPUs).
     */
    (void)dtrace_setopt(dtp, "bufsize", "512k");
    (void)dtrace_setopt(dtp, "aggsize", "512k");

    /* TODO: Add context!
    if ((dtrace_handle_buffered(dtp, bufhandler, context)) == -1)
      croak("dtrace_handle_buffered failed: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));
    */

    /* Store the pointer to the instance context struct in the hash
     * It's private, so if a user plays with it, everything breaks.
     */
    hv_store(hash, "_my_instance_ctx", strlen("_my_instance_ctx"),
             newSViv( PTR2IV(ctx) ), FALSE);

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

void
DESTROY(SV *self)
  PREINIT:
    HV  *hash;
    CTX *ctx;
    SV  **svp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle)
        dtrace_close(ctx->dtc_handle);
      free(ctx);
    }
