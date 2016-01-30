#ifndef BASE_H
#define BASE_H

#include "generic_error.h"

const int MAX_NUM_ROUTERS = 256;
const int MAX_NUM_VCS = 8;
const int MAX_NUM_IN_PORTS = 16;      // including ingress at src
const int MAX_NUM_OUT_PORTS = 16;      // including egress at src
const int MAX_NUM_OF_PACKETS_IN_TRAFFIC_BUFFER = 1024;

typedef unsigned char uchar;
typedef unsigned int  uint;

typedef char vc_t;

typedef int router_id_t;

typedef class flit_t {
 public:
  //////////////////////////////
  // for debug purposes, not needed in contest
  int id;        
  //////////////////////////////

  bool head_p;                        // true if a head flit
  bool tail_p;                        // true if a tail flit
  router_id_t dest;                   // destination router number
  
} flit_t;


// arguments
typedef struct args_t {
  public:

  bool verbose_p;    // verbose mode not needed for contest code
  int  max_cycle;
  int  num_credit_delay_cycles;
} args_t;


extern int  cycle;
extern args_t args;

#endif
