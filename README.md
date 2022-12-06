# classification_extraction_tests

DockerImages folder contains files required to create Docker images for: 
* Pytheas
* Hypoparsr
* TabbyXL
The images include the required 
* runtime environment
* test files
* scripts
to test the table extraction method against a given input file

DockerRuntimeTasks.sh runs the end-to-end table extraction test:
* Runs the Pytheas test file demo.csv through each table extraction step
* compares the using the Pytheas evaluation method
