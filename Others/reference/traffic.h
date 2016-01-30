//
// traffic.h
//   for MEMOCODE 2011 Design Contest
//   by Derek Chiou, Feb 2011

#ifndef TRAFFIC_H
#define TRAFFIC_H

#include "base.h"

typedef class one_packet_t {
 public:
  router_id_t src;    // not necessary, for debug
  router_id_t dest;   // destination of this packet
  vc_t vc;            // VC of this packet
  uchar num_flits;    // number of flits in this packet

  void fill(router_id_t src, router_id_t dest, uchar num_flits, vc_t vc);
  flit_t first();
  void dequeue();
} one_packet_t;


typedef class traffic_t {
 private:
  int head;
  int num_packets_in_buffer;
  one_packet_t packets[MAX_NUM_OF_PACKETS_IN_TRAFFIC_BUFFER];

  int num_flits_left_in_current_packet;
  int num_packets_sent;

  bool cur_flit_invalid_p;
  flit_t cur_flit;

 public:
  //////////////////////////////
  // for debug purposes
  int id;        
  //////////////////////////////

  int total_num_packets_to_send; 

  int lg_num_bits_per_hop;
  int max_num_hops;

  void init(int id, int num_packets_to_send);
  void fill(router_id_t src, router_id_t dest, uchar num_flits, vc_t vc);
  flit_t first(); // return next flit
  vc_t vc();      // return next flit's vc
  void dequeue(); // dequeue next flit
  bool not_finished();
} traffic_t;
#endif
