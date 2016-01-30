//
// router.h
//   for MEMOCODE 2011 Design Contest
//   by Derek Chiou, Feb 2011

#ifndef ROUTER_H
#define ROUTER_H

#include "base.h"
#include "my_fifo.h"


typedef struct {
  flit_t flit;
  bool full_p;

  int vc;      // only used for fb_staging 
} flit_buf_t;

typedef class router_t {
 private:
  // route_table contains next out port to reach each destination
  int route_table[MAX_NUM_ROUTERS];

  // different routers can have different numbers of in ports and out ports
  int num_in_ports;
  int num_out_ports;

  // all routers have the same number of vcs
  int num_vcs;

  // all routers have the same credit_delay 
  uchar num_credit_delay_cycles;

  // all structures are allocated to max size for convenience

  // there is a flit buffer per in_port per VC
  flit_buf_t flit_bufs[MAX_NUM_IN_PORTS][MAX_NUM_VCS];

  // fb_staging temporarily stores a flit about to be copied to
  // flit_buf to ensure that the flit is not seen before it should be.
  // Flits are copied from fb_staging to the flit_buffer in the
  // process_one_cycle_phase0
  flit_buf_t fb_staging[MAX_NUM_IN_PORTS];

  // since credit returns can be delayed by a fixed number of cycles,
  // we use a timed FIFO (data enqueued with a future time specified
  // and is dequeued only when that time is reached) to model that
  // delay.
  my_fifo_t <vc_t> credit_staging_fifo[MAX_NUM_OUT_PORTS];

  // this structure contains information about the out_ports
  struct {
    router_t *router;              // a pointer to the downstream router the out port is connected to 
    int in_port;                   // the in_port of the downstream router
    int credits[MAX_NUM_VCS];      // a separate credit per VC
    int cur_in_port[MAX_NUM_VCS];  // the in_port (per VC) that is currently connected to this out_port
  } out[MAX_NUM_OUT_PORTS];

  // this structure contains information about the in_ports
   struct { 
     router_t *router;             // the upstream router connected to this in_port
     int out_port;                 // the out_port of the upstream router
   } in[MAX_NUM_IN_PORTS]; 
    
 public:

  //////////////////////////////
  // for debug purposes
  int id;        
  //////////////////////////////

  void init(int id, int num_in_ports, int num_out_ports, int __num_vcs, int __num_credit_delay_cycles);
  void bind_forward(int my_out_port, router_t *router, int downstream_in_port, int credits);
  void bind_backwards(int my_in_port, router_t *router, int upstream_out_port);
  bool process_one_cycle_phase0();
  bool process_one_cycle_phase1();

  void accept_flit(int in_port, flit_t flit, int vc);  
  void accept_credit(int dest_port, int vc);

  bool inject_flit(flit_t flit, vc_t vc);

  void populate_route_table(router_id_t dest, int out_port) { 
    route_table[dest] = out_port; 
  };


} router_t;
#endif
