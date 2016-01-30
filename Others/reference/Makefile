all:	router.exe

router.exe:	router.cpp router.h main.cpp base.h traffic.cpp traffic.h Makefile my_fifo.h
	g++ -g -Wall router.cpp main.cpp traffic.cpp -o router

run:
	./router router_configuration_-1.txt traffic_-1.txt

clean:
	rm *~ *.exe