#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fstream>

using namespace std;
const int MAX_NUM_VCS = 8;

void read_and_write_routers(char *router_fn) {
  FILE *router_configuration_file = fopen(router_fn, "r");
  FILE *pFile = fopen ("router_configuration_file.hex","w");
  int ret;
  char str[100];
  int src_router, src_out_port, dest_router, dest_in_port;
  int num_vcs = MAX_NUM_VCS;
  int num_credit_delay_cycles = -1;

  if (router_configuration_file == NULL) {
    printf("could not open %s\n", router_fn);
    return ;
  }


  while (fgets(str, 100, router_configuration_file) != NULL) {
    if ((ret = sscanf(str, "num_credit_delay_cycles=%d", &num_credit_delay_cycles)) == 1) {
      // set num_credit_delay_cycles
      fprintf(pFile, "%x\n", num_credit_delay_cycles);

    } else if ((ret = sscanf(str, "num_vcs=%d", &num_vcs)) == 1) {
      fprintf(pFile, "%x\n", num_vcs);

    } else if ((ret = sscanf(str, "%d:%d-%d:%d", &src_router, &src_out_port, &dest_router, &dest_in_port)) == 4) {
      fprintf(pFile, "%x %x %x %x\n", src_router, src_out_port, dest_router, dest_in_port);
    }
  }
  fclose(router_configuration_file);

}

void read_and_write_traffic(char *traffic_fn) {
  FILE *traffic_file = fopen(traffic_fn, "r");
    FILE *pFile = fopen ("traffic_configuration_file.hex","w");
  char str[100];

  if (traffic_file == NULL) {
    printf("could not open %s\n", traffic_fn);
    return ;
  }

  bool route = false;
  bool packet = false;

  while (fgets(str, 100, traffic_file) != NULL) {
    int src;
    int dest;
    int num_flits;
    int ret;
    int num_packets_to_send;
    int verbose;
    int vc;
    int out_port, max_cycle;

    if ((str[0] == '%') || (str[0] == '\n')) {
      // comment, ignore

    } else if ((ret = sscanf(str, "verbose=%d", &verbose)) == 1) {
      // set verbose
    //   args.verbose_p = (verbose != 0);

    } else if ((ret = sscanf(str, "max_cycle=%d", &max_cycle)) == 1) {
        fprintf(pFile, "%x\n", max_cycle);
    } else if ((ret = sscanf(str, "route:%d->%d:%d", &src, &dest, &out_port)) == 3) {
        if(!route)
            fprintf(pFile, "//route\n");
        route=1;
      fprintf(pFile, "%x %x %x\n", src, dest, out_port);
    } else if ((ret = sscanf(str, "node %d:%d\n", &src, &num_packets_to_send)) == 2) {
        if(!packet)
            fprintf(pFile, "x //packet\n");
        packet = 1;
      fprintf(pFile, "%x %x\n", src, num_packets_to_send);

    } else if ((ret = sscanf(str, "%d:%d:%d:%d\n", &src, &dest, &vc, &num_flits)) == 4) {
        fprintf(pFile, "%x %x %x %x\n", src, dest, vc, num_flits);
    } else if (!strncmp("end", str, 3)) {
      // provides an optional way to terminate reading the traffic file
      break;
    } else {
      printf("couldn't parse \"%s\"\n", str);
      exit(1);
    }
  }
}


int main(int argc, char *argv[])
{
    if (argc != 3) {
      printf("usage: router_configuration_file traffic_file\n");
      exit(1);
    }
    read_and_write_routers(argv[1]);
    read_and_write_traffic(argv[2]);
    return 0;
}
