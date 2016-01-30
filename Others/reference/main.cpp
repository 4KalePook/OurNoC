//
// main.cpp
//   for MEMOCODE 2011 Design Contest
//   by Derek Chiou, Feb 2011

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "router.h"
#include "traffic.h"

router_t routers[MAX_NUM_ROUTERS];
traffic_t traffic[MAX_NUM_ROUTERS];

int cycle = 0;

args_t args;

void terminate_on_error() {
  exit(1);
}


void init_args() {
  args.verbose_p = false;
  args.max_cycle = 1000;
  args.num_credit_delay_cycles = 1;
}

void read_and_init_routers(char *router_fn) {
  FILE *router_configuration_file = fopen(router_fn, "r");
  int ret;
  char str[100];
  int src_router, src_out_port, dest_router, dest_in_port;
  int num_ins[MAX_NUM_ROUTERS];
  int num_outs[MAX_NUM_ROUTERS];
  int num_vcs = MAX_NUM_VCS;
  int num_credit_delay_cycles = -1;

  if (router_configuration_file == NULL) {
    ERROR_ARGS(("could not open %s\n", router_fn));
  }

  for (int i = 0; i < MAX_NUM_ROUTERS; ++i) num_ins[i] = -1;
  for (int i = 0; i < MAX_NUM_ROUTERS; ++i) num_outs[i] = -1;
    
  while (fgets(str, 100, router_configuration_file) != NULL) {
    if ((ret = sscanf(str, "num_credit_delay_cycles=%d", &num_credit_delay_cycles)) == 1) {
      // set num_credit_delay_cycles
      printf("setting num_credit_delay_cycles = %d\n", num_credit_delay_cycles);

    } else if ((ret = sscanf(str, "num_vcs=%d", &num_vcs)) == 1) {
      printf("setting num_vcs = %d\n", num_vcs);

    } else if ((ret = sscanf(str, "%d:%d-%d:%d", &src_router, &src_out_port, &dest_router, &dest_in_port)) == 4) {
      routers[src_router].bind_forward(src_out_port, &routers[dest_router], dest_in_port, 1);
      routers[dest_router].bind_backwards(dest_in_port, &routers[src_router], src_out_port);

      if (src_out_port > num_outs[src_router]) 
	num_outs[src_router] = src_out_port;

      if (dest_in_port > num_ins[dest_router]) 
	num_ins[dest_router] = dest_in_port;
    }
  }
  fclose(router_configuration_file);

  // initialize routers and traffic
  for (int i = 0; i < MAX_NUM_ROUTERS; ++i) {
    routers[i].init(i, num_ins[i]+1, num_outs[i]+1, num_vcs, num_credit_delay_cycles);
  }
}
    
  
void read_and_init_traffic(char *traffic_fn) {
  FILE *traffic_file = fopen(traffic_fn, "r");
  char str[100];

  if (traffic_file == NULL) {
    ERROR_ARGS(("could not open %s\n", traffic_fn));
  }

  // first, set all nodes to send no packets
  for (int i = 0; i < MAX_NUM_ROUTERS; ++i) 
    traffic[i].init(i, 0);

  while (fgets(str, 100, traffic_file) != NULL) {
    int src;
    int dest;
    int num_flits;
    int ret;
    int num_packets_to_send;
    int verbose;
    int vc;
    int out_port;

    if ((str[0] == '%') || (str[0] == '\n')) {
      // comment, ignore

    } else if ((ret = sscanf(str, "verbose=%d", &verbose)) == 1) {
      // set verbose
      args.verbose_p = (verbose != 0); 

    } else if ((ret = sscanf(str, "max_cycle=%d", &args.max_cycle)) == 1) {
      // set max time
      
    } else if ((ret = sscanf(str, "route:%d->%d:%d", &src, &dest, &out_port)) == 3) {
      routers[src].populate_route_table(dest, out_port);

    } else if ((ret = sscanf(str, "node %d:%d\n", &src, &num_packets_to_send)) == 2) {
      traffic[src].init(src, num_packets_to_send);

    } else if ((ret = sscanf(str, "%d:%d:%d:%d\n", &src, &dest, &vc, &num_flits)) == 4) {
      traffic[src].fill(src, dest, (uchar)num_flits, (vc_t)vc);

    } else if (!strncmp("end", str, 3)) {
      // provides an optional way to terminate reading the traffic file
      break;
    } else {
      printf("couldn't parse \"%s\"\n", str);
      exit(1);
    }
  }
}


int main(int argc, char *argv[]) {
  if (argc != 3) {
    printf("usage: router_configuration_file traffic_file\n");
    exit(1);
  }

  read_and_init_routers(argv[1]);
  read_and_init_traffic(argv[2]);

  // main loop
  bool done_traffic_p;
  bool done_routers_p;

  for (cycle = 0; cycle < args.max_cycle; ++cycle) { 
    done_traffic_p = true;
    done_routers_p = true;
    for (int r = 0; r < MAX_NUM_ROUTERS; ++r) {

      // move flits, return credits from previous cycle
      done_routers_p &= routers[r].process_one_cycle_phase0();

      // attempt to inject a flit if still need to inject flits
      if (traffic[r].not_finished()) {
	done_traffic_p = false;
	flit_t f = traffic[r].first();
	vc_t vc = traffic[r].vc();

	if (routers[r].inject_flit(f, vc)) {
	  traffic[r].dequeue();
	}
      }
    }

    for (int r = 0; r < MAX_NUM_ROUTERS; ++r) {
      done_routers_p &= routers[r].process_one_cycle_phase1();
    }
    if (done_traffic_p && done_routers_p) {
      printf("done at end of cycle %d\n", cycle);
      exit(0);
    } else if (!done_traffic_p) {
      NOTE_ARGS(("traffic not done at cycle %d", cycle));
    } else if (!done_routers_p) {
      NOTE_ARGS(("routers not done at cycle %d", cycle));
    }
  }

  printf("done at time %d, never terminated\n", cycle);
  exit(0);
}
