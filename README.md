**Reproducibility Package for “The Future of Poverty: Projecting the Impact of Climate Change on Global Poverty through 2050”
**

This folder contains the reproducibility package for the Working Paper “The Future of Poverty: Projecting the Impact of Climate Change on Global Poverty through 2050” by Johanna Fajardo-Gonzalez, Minh Nguyen and Paul Corral Rodas.

**Dependencies **

Software: Stata 16 MP (or any higher version).  Using the following ados: findpov, findsigma, groupfunction,lineup, sp_groupfunction, which are available in folder 1_code/ado.
 
**Contents of the Package **

The replication package includes the following key components: 
	Master file: Located in the root folder under the name 0_master.do. This master do file executes several do files to reproduce the results presented in the paper.
	Script files: Located in the 1_code/programs folder. These can be grouped into data generation programs and data processing programs. 
•	Data generation – Use raw data to generate indicators and, when feasible, estimate values by population groups or subnational units. Examples: 0_baseyear2022pov.do, 2_prep_growth_data.do, 3_prep_pop_data.do.
•	Data processing – Use the outputs from the data generation block to produce main results. Examples: 4_neutraldist.do, 6_gini_change_GIC.do, 9_TablesandFigures.do. 
	Data folders: These include the input data and output data folders available in the 2_data folder. The input data must not be modified by the user. 
	Final database: Located in the output data folder, named 3_output. Once all master files have been executed, the main results will be automatically generated and saved in this folder. 

**Instructions**

1.	Open the 0_master.do master file and set the working directory according to your local environment. 
2.	Upon completion, the final databases will be available in the final data folder, named 2_data/data_out.
   
**Licensing and Citation **

This work is distributed under the Creative Commons Attribution 4.0 International license (CC BY 4.0). 

Citation: Fajardo-Gonzalez, J., Nguyen, M., and Corral, P. (2025). The Future of Poverty: Projecting the Impact of Climate Change on Global Poverty through 2050. The World Bank Group.

Contact 
For inquiries, please contact Paul Corral Rodas – pcorralrodas@worldbank.org -, Minh Nguyen - mnguyen3@worldbank.org -, and Johanna Fajardo-Gonzalez – jfajardog@worldbank.org

 

