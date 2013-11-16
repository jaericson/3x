# <i class="icon-beaker"></i> 3X

## A tool for eXecutable eXploratory eXperiments
<span class="sans-serif">3X</span> is a software tool for conducting computational experiments in a systematic way.
<span class="sans-serif">3X</span> provides a standard yet configurable structure to execute a wide variety of experiments.
It organizes code/inputs/outputs for the experiment, records results, and lets users visualize the data and drive execution interactively.

### Motivation
Organizing the data that goes into and comes out of experiments, as well as maintaining the infrastructure for running them, is generally regarded as a tedious and mundane task.
Often times we end up in a suboptimal environment improvised and hard-coded for each experiment.
The problem is exacerbated when the experiments must be performed iteratively for exploring a large parameter space.
It is obvious that easing this burden will enable us to more quickly make interesting discoveries from the data our experiments produce.
So-called "data scientists" are emerging everywhere these days to ask questions in the form of computational experiments, and to discover new facts from the "big data" their institutions have accumulated.
In fact, these computational and data-driven approaches have long been a standard method for doing science in many domains, and we see ever growing number of fields depending on computational experiments.

### What 3X Provides
* A standard filesystem layout for an *experiment repository*, where you can organize the code of your experiment program as well as its input data and output definition in a transparent way, and where <span class="sans-serif">3X</span> can keep complete records of the execution results in a systematic and storage-efficient manner.

* *Operations on the experiment* to create the repository, to define your experiment, to plan/control/manage executions on various target environments, and to access results data, either through a scriptable command-line interface, or an intuitive graphical user interface.

* *Instant, interactive visualizations* of the execution results as tables and charts to let you explore and analyze the data as soon as your computations finish.



## Further Information

### Features of 3X
<span class="sans-serif">**[3X Features Overview][]**</span> gives a tour of all features <span class="sans-serif">3X</span> provides in the order of a typical workflow, and introduces terms and concepts used by the software.

### Installing 3X
<span class="sans-serif">**[3X Installation Instructions][]**</span> contains instructions to download, build and install <span class="sans-serif">3X</span> on your systems.
<span class="sans-serif">3X</span> is packaged as a single self-contained, executable file, so installation is basically copying one file to a special location on your system.

### Getting Started with 3X
<span class="sans-serif">**[3X Tutorial with Examples][]**</span> contains detailed step-by-step instructions and screenshots using real examples.
By following the tutorial, you can get hands-on experience of <span class="sans-serif">3X</span>, and get yourself ready to use it for your own experiments.
Reading the <span class="sans-serif">[3X Features Overview][]</span> first is recommended to make yourself familiar with the terms and concepts.



## People
* [Jaeho Shin][netj]
* [Andreas Paepcke][Paepcke]
* [Jennifer Widom][Widom]


<!--
## Papers / Talks
-->

----

[3X Features Overview]: docs/features/
[3X Installation Instructions]: docs/install/
[3X Tutorial with Examples]: docs/tutorial/

[netj]: http://cs.stanford.edu/~netj/
[paepcke]: http://infolab.stanford.edu/~paepcke/
[widom]: http://infolab.stanford.edu/~widom/



<link rel="stylesheet" type="text/css" href="http://netdna.bootstrapcdn.com/font-awesome/3.0.2/css/font-awesome.css">
