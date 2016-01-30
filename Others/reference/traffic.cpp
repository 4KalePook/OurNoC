//
// traffic.cpp
//   for MEMOCODE 2011 Design Contest
//   by Derek Chiou, Feb 2011

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "traffic.h"

static int flit_id = 0;  // for testing

void one_packet_t::fill(router_id_t __src, router_id_t __dest, uchar __num_flits, vc_t __vc) {
  src = __src;
  dest = __dest;
  num_flits = __num_flits;
  vc = __vc;

  if (vc > MAX_NUM_VCS) {
    ERROR("vc exceeded MAX_NUM_VCS");
  }
}
    
void traffic_t::init(int __id, int __total_num_packets_to_send) {
  id = __id;
  num_packets_in_buffer = 0;
  num_packets_sent = 0;
  total_num_packets_to_send = __total_num_packets_to_send;

  head = num_flits_left_in_current_packet = 0;
  cur_flit_invalid_p = true;
}

flit_t traffic_t::first() {
  if (cur_flit_invalid_p) { // create flit from current packet
    cur_flit_invalid_p = false;
    cur_flit.id = flit_id;  // for testing

    if (num_flits_left_in_current_packet == 0) { // create new head flit
      cur_flit.dest = packets[head].dest;
      num_flits_left_in_current_packet = packets[head].num_flits;

      cur_flit.head_p = true;
    } else {
      cur_flit.head_p = false;
    }
    cur_flit.tail_p = (num_flits_left_in_current_packet == 1) ? true : false; 
  }
  return(cur_flit);
}

vc_t traffic_t::vc() {
  return(packets[head].vc);
}

void traffic_t::dequeue() {
  ++flit_id;
  cur_flit_invalid_p = true;
  if (--num_flits_left_in_current_packet == 0) {
    head = (head + 1) % num_packets_in_buffer;
    ++num_packets_sent;
  }
}

bool traffic_t::not_finished() {
  return(num_packets_sent < total_num_packets_to_send);
}
  

void traffic_t::fill(router_id_t src, router_id_t dest, uchar num_flits, vc_t vc) {
  packets[num_packets_in_buffer++].fill(src, dest, num_flits, vc);

  if (num_packets_in_buffer > MAX_NUM_OF_PACKETS_IN_TRAFFIC_BUFFER) {
    ERROR("exceeded maximum number of packets");
  }
}

