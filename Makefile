build: demo

msc:
	cd msc.d && ln -s ../ms.d ./.ms.d
	ln -s ms.sh msc.sh
	bash msc.sh __make__

demo: msc
	bash msc demo.ms

clean:
	rm -rf demo.sh msc msc.sh msc.d/.ms.d
