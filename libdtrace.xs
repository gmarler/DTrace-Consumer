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
setopt(SV *self, char *option, ...)
  PREINIT:
    HV           *hash;
    CTX          *ctx;
    SV           **svp;
    int           rval;
    dtrace_hdl_t *dtp;
    char         *my_option;
    char         *value;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("setopt: No valid DTrace handle!");
      }
    }

    if (items == 1) {
      croak("setopt: requires an option and possibly a value for it");
    }
    if (items >= 2) {
      if (! SvPOK( ST(1) )) {
        croak("setopt: Invalid option specified");
      }
      my_option = (char *)SvPV_nolen(ST(1));
    }
    if (items == 3) {
      if (SvPOK( ST(2) )) {
        value = (char *)(SvPV_nolen(ST(2)));
      } else
        croak("setopt: Invalid value specified");
      rval = dtrace_setopt(dtp, my_option, value);
    } else {
      rval = dtrace_setopt(dtp, my_option, NULL);
    }

    if (rval != 0) {
      croak("Couldn't set option '%s': %s", *option,
             dtrace_errmsg(dtp, dtrace_errno(dtp)));
    }


void
strcompile(SV *self, char *program)
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
    dtrace_prog_t      *dp;
    dtrace_proginfo_t   info;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("strcompile: No valid DTrace handle!");
      }
    }

    /* If less than 2 args passed in, we're missing a program */
    if (items < 2)
      croak("strcompile: Expected a program!");

    if ((dp = dtrace_program_strcompile(dtp, program,
              DTRACE_PROBESPEC_NAME, 0, 0, NULL)) == NULL)
      croak("Couldn't compile '%s': %s", program,
            dtrace_errmsg(dtp, dtrace_errno(dtp)));

    if (dtrace_program_exec(dtp, dp, &info) == -1)
      croak("Couldn't execute '%s': %s", program,
            dtrace_errmsg(dtp, dtrace_errno(dtp)));


void
go(SV* self)
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("go: No valid DTrace handle!");
      }
    }

    if (dtrace_go(dtp) == -1)
      croak("Couldn't enable tracing: %s",
            dtrace_errmsg(dtp, dtrace_errno(dtp)));

void
stop(SV* self)
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
  CODE:
    hash = (HV *)SvRV(self);
    svp = hv_fetchs( hash, "_my_instance_ctx", FALSE );

    if ( svp && SvOK(*svp) ) {
      ctx = (CTX *)SvIV(*svp);
      if (ctx->dtc_handle) {
        dtp = ctx->dtc_handle;
      } else {
        croak("stop: No valid DTrace handle!");
      }
    }

    if (dtrace_stop(dtp) == -1)
      croak("Couldn't disable tracing: %s",
            dtrace_errmsg(dtp, dtrace_errno(dtp)));


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
