
/*   #define PERL_NO_GET_CONTEXT */
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
  SV *           dtc_callback;
  int            dtc_error;
  /* dtc_ranges    */
  dtrace_aggvarid_t dtc_ranges_varid;
} CTX;

/* C Functions */

const char *
action(const dtrace_recdesc_t *rec, char *buf, int size)
{
  static struct {
    dtrace_actkind_t action;
    const char *name;
  } act[] = {
    { DTRACEACT_NONE,       "<none>" },
    { DTRACEACT_DIFEXPR,    "<DIF expression>" },
    { DTRACEACT_EXIT,       "exit()" },
    { DTRACEACT_PRINTF,     "printf()" },
    { DTRACEACT_PRINTA,     "printa()" },
    { DTRACEACT_LIBACT,     "<library action>" },
    { DTRACEACT_USTACK,     "ustack()" },
    { DTRACEACT_JSTACK,     "jstack()" },
    { DTRACEACT_USYM,       "usym()" },
    { DTRACEACT_UMOD,       "umod()" },
    { DTRACEACT_UADDR,      "uaddr()" },
    { DTRACEACT_STOP,       "stop()" },
    { DTRACEACT_RAISE,      "raise()" },
    { DTRACEACT_SYSTEM,     "system()" },
    { DTRACEACT_FREOPEN,    "freopen()" },
    { DTRACEACT_STACK,      "stack()" },
    { DTRACEACT_SYM,        "sym()" },
    { DTRACEACT_MOD,        "mod()" },
    { DTRACEAGG_COUNT,      "count()" },
    { DTRACEAGG_MIN,        "min()" },
    { DTRACEAGG_MAX,        "max()" },
    { DTRACEAGG_AVG,        "avg()" },
    { DTRACEAGG_SUM,        "sum()" },
    { DTRACEAGG_STDDEV,     "stddev()" },
    { DTRACEAGG_QUANTIZE,   "quantize()" },
    { DTRACEAGG_LQUANTIZE,	"lquantize()" },
    { DTRACEAGG_LLQUANTIZE,	"llquantize()" },
    { DTRACEACT_NONE,	NULL },
  };

  dtrace_actkind_t action = rec->dtrd_action;
  int i;

  for (i = 0; act[i].name != NULL; i++) {
    if (act[i].action == action)
      return (act[i].name);
  }

  (void) snprintf(buf, size, "<unknown action 0x%x>", action);

  return (buf);
}

boolean_t
valid(const dtrace_recdesc_t *rec)
{
  dtrace_actkind_t action = rec->dtrd_action;

  switch (action) {
    case DTRACEACT_DIFEXPR:
    case DTRACEACT_SYM:
    case DTRACEACT_MOD:
    case DTRACEACT_USYM:
    case DTRACEACT_UMOD:
    case DTRACEACT_UADDR:
      return (B_TRUE);

    default:
      return (B_FALSE);
  }
}

SV *
record(const dtrace_recdesc_t *rec, caddr_t addr)
{
  switch (rec->dtrd_action) {
    case DTRACEACT_DIFEXPR:
      switch (rec->dtrd_size) {
        case sizeof(uint64_t):
          return (sv_2mortal(newSViv(*((int64_t *)addr))));

        case sizeof(uint32_t):
          return (sv_2mortal(newSViv(*((int32_t *)addr))));

        case sizeof(uint16_t):
          return (sv_2mortal(newSViv(*((int16_t *)addr))));

        case sizeof(uint8_t):
          return (sv_2mortal(newSViv(*((int8_t *)addr))));

        default:
          return (sv_2mortal(newSVpv((const char *)addr,0)));
      }

    case DTRACEACT_SYM:
    case DTRACEACT_MOD:
    case DTRACEACT_USYM:
    case DTRACEACT_UMOD:
    case DTRACEACT_UADDR:
      dtrace_hdl_t *dtp = dtc_handle;
      char buf[2048], *tick, *plus;

      buf[0] = '\0';

      if (DTRACEACT_CLASS(rec->dtrd_action) == DTRACEACT_KERNEL) {
        uint64_t pc = ((uint64_t *)addr)[0];
        dtrace_addr2str(dtp, pc, buf, sizeof(buf) - 1);
      } else {
        uint64_t pid = ((uint64_t *)addr)[0];
        uint64_t pc  = ((uint64_t *)addr)[1];
        dtrace_uaddr2str(dtp, pid, pc, buf, sizeof(buf) - 1);
      }

      if (rec->dtrd_action == DTRACEACT_MOD ||
          rec->dtrd_action == DTRACEACT_UMOD) {
        /*
         * If we're looking for the module name, we'll
         * return everything to the left of the left-most
         * tick -- or "<undefined>" if there is none.
         */
        if ((tick = strchr(buf, '`')) == NULL)
          return (sv_2mortal(newSVpv("<unknown>")));

        *tick = '\0';
      } else if (rec->dtrd_action == DTRACEACT_SYM ||
                 rec->dtrd_action == DTRACEACT_USYM) {
        /*
         * If we're looking for the symbol name, we'll
         * return everything to the left of the right-most
         * plus sign (if there is one).
         */
        if ((plus = strrchr(buf, '+')) != NULL)
          *plus = '\0';
      }

      return (sv_2mortal(newSVpv(buf)));
  }

  return (sv_2mortal(newSViv(-1)));
}

int
bufhandler(const dtrace_bufdata_t *bufdata, void *arg)
{
  dSP;
  dtrace_probedata_t     *data = bufdata->dtbda_probe;
  const dtrace_recdesc_t *rec  = bufdata->dtbda_recdesc;

  /* TODO: DTrace Consumer (dtc) will be passed in as arg  */
  CTX *dtc = (CTX *)arg;


  if (rec == NULL || rec->dtrd_action != DTRACEACT_PRINTF)
    return( DTRACE_HANDLE_OK );

  /* TODO: Call probedesc to get probe hashref  */
  HV *probe_hash;
  /* TODO: Create a hashref for record */
  HV *rec_hash = (HV*)sv_2mortal((SV*)newHV());
  hv_store(rec_hash, "data", strlen("data"), newSVpv(bufdata->dtbda_buffered));

  rec_href   = sv_2mortal(newSVrv(rec_hash));

  /* TODO: call the callback with array of the probe and record description */

  return( DTRACE_HANDLE_OK );
}

int
consume_callback_caller(const dtrace_probedata_t *data,
                        const dtrace_recdesc_t   *rec,
                        void                     *arg)
{
  dSP;
  int count;
  SV  *probe_href;
  SV  *record_href;
  SV  *callback = ((CTX *)arg)->dtc_callback;
  CTX *dtc      = (CTX *)arg;

  ENTER;
  SAVETMPS;

  dtrace_probedesc_t *pd = data->dtpda_pdesc;

  /*  HV *probe_hash = dtc->probedesc(data->dtpda_pdesc); */
  HV *probe_hash = dtc->probedesc(data->dtpda_pdesc);
  HV *rec_hash;

  probe_href = sv_2mortal(newSVrv(probe_hash));

  /* TODO: Handle case where the rec is NULL */
  if (rec == NULL) {
  }

  if (!dtc->valid(rec)) {
    char errbuf[256];

    /* If this is a printf(), we defer to the bufhandler. */
    if (rec->dtrd_action == DTRACEACT_PRINTF)
      return (DTRACE_CONSUME_THIS);

    dtc->dtc_error =
      dtc->error("unsupported action %s in record for %s:%s:%s:%s\n",
                 dtc->action(rec, errbuf, sizeof(errbuf)),
                 pd->dtpd_provider, pd->dtpd_mod,
                 pd->dtpd_func, pd->dtpd_name);
    return (DTRACE_CONSUME_ABORT);
  }

  rec_hash = (HV*)sv_2mortal((SV*)newHV());

  hv_store(rec_hash, "data", strlen("data"), newSVpv(dtc->record(rec, data->dtpda_data)));
 
  rec_href   = sv_2mortal(newSVrv(rec_hash));

  PUSHMARK(SP);
  /* TODO: push the probe_href and record_href onto the stack for the callback
   *       to pick up */
  XPUSHs(probe_href);
  XPUSHs(desc_href);
  PUTBACK;

  count = call_sv(callback, G_SCALAR);

  SPAGAIN;

  if (count != 1)
    croak("consume_callback_caller: FAIL!\n");

  /* TODO: Pop something off the stack here? */

  FREETMPS;
  LEAVE;

  return(DTRACE_CONSUME_THIS);
}

/* And now the XS code, for C functions we want to access directly from Perl */

MODULE = Devel::libdtrace              PACKAGE = Devel::libdtrace

# XS code

PROTOTYPES: ENABLED

SV *
new( const char *class )
  PREINIT:
    dtrace_hdl_t *dtp;
    CTX* ctx = (CTX *)calloc( 1, sizeof(CTX) );
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

    if ((dtrace_handle_buffered(dtp, bufhandler, ctx)) == -1)
      croak("dtrace_handle_buffered failed: %s",
            dtrace_errmsg(dtp,dtrace_errno(dtp)));

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

    /* Die early if too many arguments specified */
    if (items > 3) {
      croak("Too many arguments specified");
    }
    /*  This should never get hit - the XS level should emit a Usage: message
     *  instead and dire on it's own */
    if (items == 1) {
      croak("setopt: requires an option and possibly a value for it");
    }
    /* We've got at least an option specified here; we test for >= 2 because
     * some options don't have associated values, ever, and others do */
    if (items >= 2) {
      if (! SvPOK( ST(1) )) {
        croak("setopt: Option must be a string");
      }
      my_option = (char *)SvPV_nolen(ST(1));
    }
    /* An attempt to specify a value for the option above has been made - it too
     * must be in string format */
    if (items == 3) {
      if (SvPOK( ST(2) )) {
        value = (char *)(SvPV_nolen(ST(2)));
      } else {
        croak("setopt: Value must be a string");
      }
      rval = dtrace_setopt(dtp, my_option, value);
    } else {
      rval = dtrace_setopt(dtp, my_option, NULL);
    }

    if (rval != 0) {
      croak("Couldn't set option '%s': %s", my_option,
             dtrace_errmsg(dtp, dtrace_errno(dtp)));
    }


void
strcompile(SV *self, ... )
  PREINIT:
    HV                 *hash;
    CTX                *ctx;
    SV                 **svp;
    dtrace_hdl_t       *dtp;
    dtrace_prog_t      *dp;
    dtrace_proginfo_t   info;
    char               *program;
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

    if (! SvPOK( ST(1) )) {
      croak("strcompile: Program must be a string");
    }
    program = (char *)SvPV_nolen(ST(1));

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


int
consume(SV *self, SV *callback )
  PREINIT:
    HV                  *hash;
    CTX                 *ctx;
    SV                  **svp;
    dtrace_hdl_t        *dtp;
    dtrace_workstatus_t  status;
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

    /* TODO: Set up callback and it's args */
    /* Take a copy of the callback into our self*/
    if (ctx->dtc_callback == (SV*)NULL) {
      /* First time through, so create a new SV */
      ctx->dtc_callback = newSVsv(callback);
    } else {
      SvSetSV(ctx->dtc_callback, callback);
    }

    status = dtrace_work(dtp, NULL, NULL, consume_callback_caller, ctx);

    if (status == -1 && !ctx->dtc_error) {
      return(ctx->dtc_error);
    }

HV *
probedesc(const dtrace_probedesc_t *pd)
  PREINIT:
    HV *probe;
  CODE:
    probe = (HV*)sv_2mortal((SV*)newHV());

    hv_store(probe, "provider", strlen("provider"), newSVpv(pd->dtpd_provider));
    hv_store(probe, "module",   strlen("module"),   newSVpv(pd->dtpd_mod));
    hv_store(probe, "function", strlen("function"), newSVpv(pd->dtpd_func));
    hv_store(probe, "name",     strlen("name"),     newSVpv(pd->dtpd_name));

    RETVAL = probe;
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

