use strict;
use warnings;
use v5.18.1;
use feature qw(say);

use Test::Most;
use Scalar::Util qw(reftype);
use Data::Dumper;
use IO::Async::Timer::Periodic;
use IO::Async::Loop;

use_ok( 'DTrace::Consumer' );


my $dtc = DTrace::Consumer->new();

isa_ok( $dtc, 'DTrace::Consumer' );
can_ok( $dtc, qw( strcompile go aggwalk stop ) );

my $prog = q\
this string fstype;

fbt::fop_read:entry,
fbt::fop_write:entry,
fbt::fop_ioctl:entry,
fbt::fop_access:entry,
fbt::fop_getattr:entry,
fbt::fop_setattr:entry,
fbt::fop_lookup:entry,
fbt::fop_create:entry,
fbt::fop_remove:entry,
fbt::fop_link:entry,
fbt::fop_rename:entry,
fbt::fop_mkdir:entry,
fbt::fop_rmdir:entry,
fbt::fop_readdir:entry,
fbt::fop_symlink:entry,
fbt::fop_readlink:entry,
fbt::fop_fsync:entry,
fbt::fop_getpage:entry,
fbt::fop_putpage:entry,
fbt::fop_map:entry,
fbt::fop_open:entry
/((self->vnode0 == NULL))/{
	self->vnode0 = arg0;
	self->depth0 = stackdepth;
	self->latency0 = timestamp;
}

fbt::fop_open:return
/((((((self->vnode0) != NULL)))) && (((((self->depth0) != NULL)))) && (((((self->latency0) != NULL)))) && (((((this->fstype = stringof((*((vnode_t**)self->vnode0))->v_op->vnop_name)) != NULL || 1)))) && (self->depth0 == stackdepth && self->vnode0 != NULL && (this->fstype == "ufs" || this->fstype == "zfs" || this->fstype == "dev" || this->fstype == "dev fs" || this->fstype == "proc" || this->fstype == "lofs" || this->fstype == "tmpfs" || this->fstype == "nfs")))/{
	@[((probefunc + 4)),this->fstype] = llquantize((timestamp - self->latency0), 10, 3, 11, 100);
}

fbt::fop_read:return,
fbt::fop_write:return,
fbt::fop_ioctl:return,
fbt::fop_access:return,
fbt::fop_getattr:return,
fbt::fop_setattr:return,
fbt::fop_lookup:return,
fbt::fop_create:return,
fbt::fop_remove:return,
fbt::fop_link:return,
fbt::fop_rename:return,
fbt::fop_mkdir:return,
fbt::fop_rmdir:return,
fbt::fop_readdir:return,
fbt::fop_symlink:return,
fbt::fop_readlink:return,
fbt::fop_fsync:return,
fbt::fop_getpage:return,
fbt::fop_putpage:return,
fbt::fop_map:return
/((((((self->vnode0) != NULL)))) && (((((self->depth0) != NULL)))) && (((((self->latency0) != NULL)))) && (((((this->fstype = stringof(((vnode_t*)self->vnode0)->v_op->vnop_name)) != NULL || 1)))) && (self->depth0 == stackdepth && self->vnode0 != NULL && (this->fstype == "ufs" || this->fstype == "zfs" || this->fstype == "dev" || this->fstype == "dev fs" || this->fstype == "proc" || this->fstype == "lofs" || this->fstype == "tmpfs" || this->fstype == "nfs")))/{
	@[((probefunc + 4)),this->fstype] = llquantize((timestamp - self->latency0), 10, 3, 11, 100);
}

fbt::fop_read:return,
fbt::fop_write:return,
fbt::fop_ioctl:return,
fbt::fop_access:return,
fbt::fop_getattr:return,
fbt::fop_setattr:return,
fbt::fop_lookup:return,
fbt::fop_create:return,
fbt::fop_remove:return,
fbt::fop_link:return,
fbt::fop_rename:return,
fbt::fop_mkdir:return,
fbt::fop_rmdir:return,
fbt::fop_readdir:return,
fbt::fop_symlink:return,
fbt::fop_readlink:return,
fbt::fop_fsync:return,
fbt::fop_getpage:return,
fbt::fop_putpage:return,
fbt::fop_map:return,
fbt::fop_open:entry
/((self->depth0 == stackdepth))/{
	(self->vnode0) = 0;
	(self->depth0) = 0;
	(self->latency0) = 0;
}

\;

#diag $prog;

lives_ok(
  sub {
    $dtc->strcompile($prog);
  },
  'strcompile of 1st lquantize program'
);

lives_ok(
  sub {
    $dtc->go();
  },
  'Run go() on 1st lquantize program'
);

lives_ok(
  sub {
    $dtc->aggwalk(
      sub {
        # diag Data::Dumper::Dumper( \@_ );
        my ($varid, $key, $val) = @_;

      }
    );
  },
  'walking lquantize agg 1 shows correct data'
);

sub test_drops {
  my $loop = IO::Async::Loop->new;
  
  my $iterations;
  my $timer;
  $timer = IO::Async::Timer::Periodic->new(
     interval => 1,
   
     on_tick => sub {
       $iterations++;
       say "on_tick ITERATION: $iterations";
       $dtc->aggwalk(
         sub {
           say "agg_walk CALLBACK ITERATION: $iterations";
           # diag Data::Dumper::Dumper( \@_ );
           my ($varid, $key, $val) = @_;
  
           if ($iterations > 7) {
             # Stop the timer
             $loop->remove( $timer );
             $loop->loop_stop();
             $dtc->stop();
           }
           # diag Dumper( $rec );
         }
       );
     },
  );
   
  $timer->start;
   
  $loop->add( $timer );
   
  $loop->run;
}

# This might drop nothing, and it might drop something - handle it
stderr_like(\&test_drops,
            qr/(|^\d+\s+dynamic\s+variable\s+drops)/smx,
            'drops produce messages on STDERR');


done_testing();
