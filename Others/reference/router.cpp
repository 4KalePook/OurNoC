//
// router.cpp
//   for MEMOCODE 2011 Design Contest
//   by Derek Chiou, Feb 2011

#include <stdio.h>
#include <stdlib.h>
#include "router.h"


void router_t::init(int __id, int __num_in_ports, int __num_out_ports, int __num_vcs, int __num_credit_delay_cycles) {
  id = __id;
  num_in_ports = __num_in_ports;
  num_out_ports = __num_out_ports;
  num_credit_delay_cycles = __num_credit_delay_cycles;


  // init all flit buffers to be empty
  for (int i = 0; i < num_in_ports; ++i) {
    for (int f = 0; f < __num_vcs; ++f) {
      flit_bufs[i][f].full_p = false;
    }
    fb_staging[i].full_p = false;
  }
  for (int o = 0; o < num_out_ports; ++o) {
    for (int vc = 0; vc < __num_vcs; ++vc) {
      out[o].credits[vc] = 1; // only 1 supported currently
      out[o].cur_in_port[vc] = -1;
    }
    credit_staging_fifo[o].init_time("credit_fifo", __num_credit_delay_cycles, -1);
  }
}

bool router_t::process_one_cycle_phase0() {
  bool done_p = true;

  // copy flit from staging flit buffer to actual flit buffer
  for (int in_port = 0; in_port < num_in_ports; ++in_port) {
    if (fb_staging[in_port].full_p) {
      done_p = false;

      int vc = fb_staging[in_port].vc;

      NOTE_ARGS(("r%d:s%d moving flit %d into flit buffer, vc %d", id, in_port, fb_staging[in_port].flit.id, vc));

      if (flit_bufs[in_port][vc].full_p) { 
	ERROR("error, shouldn't assign into full flit buffer\n");
      }
      flit_bufs[in_port][vc] = fb_staging[in_port];

      fb_staging[in_port].full_p = false;
    }
  }

  for (int out_port = 0; out_port < num_out_ports; ++out_port) {
    if (!credit_staging_fifo[out_port].tempty(cycle)) {
      int vc = credit_staging_fifo[out_port].tdequeue(cycle);
      ++out[out_port].credits[vc];
      NOTE_ARGS(("r%d:d%d incrementing credit for vc %d", id, out_port, vc));
    }

    if (!credit_staging_fifo[out_port].empty()) { // something in fifo which will show up in the future
      done_p = false;
    }
  }

  return(done_p);
}


bool router_t::process_one_cycle_phase1() {
  bool done_router_p = true;

  // due to flit buffer bandwidth limitations, each source can only be usd once per cycle.
  bool in_free_p[MAX_NUM_IN_PORTS];

  // each link can only be used once per cycle.  
  bool out_link_free_p[MAX_NUM_OUT_PORTS];

  for (int i = 0; i < num_in_ports; ++i) 
    in_free_p[i] = true;
    
  for (int i = 0; i < num_out_ports; ++i) 
    out_link_free_p[i] = true;  

  // main arbitration loop.  The lower the virtual channel number, the higher priority
  for (int vc = 0; vc < MAX_NUM_VCS; ++vc) {
    for (int in_port = 0; in_port < num_in_ports; ++in_port) {
      if (in_free_p[in_port]) {
	flit_buf_t *fb = &flit_bufs[in_port][vc];
	int out_port = route_table[fb->flit.dest];
      
	if (fb->full_p) {                // there is a flit
	  done_router_p = false;         // as long as one flit exists in any router, not done
	  
	  if (out_link_free_p[out_port] // link is free
	      && ((out[out_port].cur_in_port[vc] < 0) || // no src is reserving dest
		  (out[out_port].cur_in_port[vc] == in_port))){// dest reserved for cur in port

	    if (out_port == 0) { // extract
	      NOTE_ARGS(("r%d extracting flit %d", id, fb->flit.id));
	      
	      // reserve dest_port*vc if flit is not a tail flit and deallocate if it is a tail flit
	      if (fb->flit.tail_p) out[out_port].cur_in_port[vc] = -1;
	      else out[out_port].cur_in_port[vc] = in_port;
	      
	      fb->full_p = false;

	      // consume destination link and source flit buffer bandwidth
	      out_link_free_p[out_port] = false;
	      in_free_p[in_port] = false;

	      // extract doesn't consume credits, so credits aren't decremented
	    
	      // however, a credit needs to be returned 
	      in[in_port].router->accept_credit(in[in_port].out_port, vc);

	      
	    
	    } else if (out[out_port].credits[vc] > 0) {
	      NOTE_ARGS(("r%d:s%d:d%d sending flit %d", id, in_port, out_port, fb->flit.id)); 
	    
	      // ensure that flits from different packets aren't interleaved on same vc
	      if (fb->flit.tail_p) out[out_port].cur_in_port[vc] = -1;
	      else out[out_port].cur_in_port[vc] = in_port;
	      
	      // send flit and credit at the same time
	      out[out_port].router->accept_flit(out[out_port].in_port, fb->flit, vc);
	      
	      if (in_port > 0) { // src_port == 0 is insert
		in[in_port].router->accept_credit(in[in_port].out_port, vc);
	      }
	      
	      --out[out_port].credits[vc];  
	      fb->full_p = false;

	      // consume destination link and source flit buffer bandwidth
	      out_link_free_p[out_port] = false;
	      in_free_p[in_port] = false;
	    }
	  }
	}
      }
    }
  }
  return(done_router_p);
}

  
void router_t::accept_flit(int src_port, flit_t flit, int vc) {
  if (fb_staging[src_port].full_p) {
    ERROR_ARGS(("r%d:s%d failed to accept flit %d, vc %d due to staging being full", flit.id, id, src_port, vc));
  }
  NOTE_ARGS(("r%d:s%d accepting flit %d, vc %d", id, src_port, flit.id, vc));
  fb_staging[src_port].full_p = true;
  fb_staging[src_port].flit = flit;
  fb_staging[src_port].vc = vc;
}

void router_t::accept_credit(int out_port, int vc) {
  NOTE_ARGS(("%d:%d for vc %d", id, out_port, vc));
  
  if (credit_staging_fifo[out_port].full_p()) {
    ERROR("tried to accept credit when staging is full");
  }
  credit_staging_fifo[out_port].tenqueue(cycle + num_credit_delay_cycles, vc);
}

// return true if flit was injected 
bool router_t::inject_flit(flit_t flit, vc_t vc) {
  if (flit_bufs[0][(int)vc].full_p) {
    NOTE_ARGS(("failed injecting flit %d into r%d", flit.id, id));
    return(false);
  } else {
    NOTE_ARGS(("injected flit %d into r%d", flit.id, id));
  }

  flit_bufs[0][(int)vc].flit = flit;
  flit_bufs[0][(int)vc].full_p = true;
  return(true);
}

  

void router_t::bind_forward(int my_out_port, router_t *dest_router, int dest_in_port, int credits) {

  NOTE_ARGS(("binding %d:%d to %d:%d", id, my_out_port, dest_router->id, dest_in_port));
  
  out[my_out_port].router = dest_router;
  out[my_out_port].in_port = dest_in_port;
  for (int vc = 0; vc < MAX_NUM_VCS; ++vc) {
    out[my_out_port].credits[vc] = credits;
  }
}

void router_t::bind_backwards(int my_src_port, router_t *src_router, int src_out_port) {
  NOTE_ARGS(("binding src of dest %d:%d to %d:%d", id, my_src_port, src_router->id, src_out_port));

  in[my_src_port].router = src_router;
  in[my_src_port].out_port = src_out_port;
}

  
  
  


