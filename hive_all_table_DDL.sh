JDBC_STRING=""
LINE_SEPARATOR="---------------------------------------------------------------------"
LINE_SEPARATOR_MINI="------------"
declare -a db_array
db_file=hive_databases.txt
FILETIME="$(date +%Y''%m''%d''%H''%M''%S)"

#Check if running user has a valid kerberos ticket
klist -s
if [ $? != 0 ]; then
	echo "You do not have a valid kerberos ticket. Please kinit and get a ticket before running again."
	exit 1
fi

if [ -e $db_file ];
then
        db_array=( $(cat $db_file) )
        echo "I found file '$db_file' and will get all table DDLs for the databases in that file."
else
#Check whether user wants to get DDLs for all databases or specify the databases
while true; do
        read -p "Which databases do you want to get DDLs for? | ALL (1) or Manually entered (2): " datbase_ddl_input
                case $datbase_ddl_input in
                        [1] )
                                break;;
                        [2] )
                                break;;
                        * )
                                echo "Please enter a 1 or 2 for: ALL (1) or Manually entered (2) ";;
                esac
done

echo ""
if [ $datbase_ddl_input == 1 ]; then
        echo "You chose: ALL"
else
        echo "You chose: Manually entered"
fi
echo ""
while true; do
        read -p "Is this correct? (y/n): " yn
                case $yn in
                        [yY] | [yY][Ee][Ss] )
                                break;;
                        [nN] | [nN][oO] )
                                exit 0;;
                        * )
                                echo "Please answer yes or no (y/n) ";;
                esac
done

if [ $datbase_ddl_input == 1 ]; then
	beeline --showHeader=false --outputformat="csv2" --silent -u "$JDBC_STRING" -e 'show databases;' > hive_databases.txt
	db_array=( $(cat hive_databases.txt) )
	rm hive_databases.txt
elif [ $datbase_ddl_input == 2 ]; then
	#Prompt user to enter in databases
	echo ""
	echo "Here is a list of possible databases to choose from:"
	beeline --showHeader=false --outputformat="csv2" --silent -u "$JDBC_STRING" -e 'show databases;'
	echo ""
	echo "To get table DDLs for databases, I need a list of databases to query."
	echo -n "Please enter in a database name: "
	read db_name
	db_array=("${db_array[@]}" $db_name)
	echo "You entered: "$db_name

	#check if there are more databases
	MORE_DBS="y"
	if [ "$MORE_DBS" == y ];
        then
       		while true; do
                	read -p "Do you have another database (y/n): " yn
                	case $yn in
                        	[yY] | [yY][Ee][Ss] )
                                	echo -n "Please enter in a database name: "
                                	read db_name
                                	db_array=("${db_array[@]}" $db_name)
                                	echo "You entered: "$db_name;;
                        	[nN] | [nN][oO] )
                                	MORE_DBS="n"
                                	break;;
                        	* )
                                	echo "Please answer yes or no (y/n) ";;
                	esac
        	done
	fi
	
	echo ""
	echo "$LINE_SEPARATOR"
	echo "You have entered the following Hive databases:"
	printf '%s\n' "${db_array[@]}"
	echo ""
	while true; do
        	read -p "Is this correct? (y/n): " yn
                	case $yn in
                        	[yY] | [yY][Ee][Ss] )
                                	break;;
                        	[nN] | [nN][oO] )
                                	exit 0;;
                        	* )
                                	echo "Please answer yes or no (y/n) ";;
                	esac
	done
	else
        echo ""
        echo "Hmmm I'm seeiming to have an issue reading your database list. I will have to quit..."
        exit 1;
fi

fi

echo ""
echo "$LINE_SEPARATOR"
echo "Hive databases:"
printf '%s\n' "${db_array[@]}"
echo ""

for i in "${db_array[@]}"
do
	echo "$LINE_SEPARATOR"
	echo "Hive tables in database: $i"
	beeline --showHeader=false --outputformat="csv2" --silent -u "$JDBC_STRING" -e 'use '"$i"';show tables;' | tee hive_"$i"_tables_$FILETIME.txt
	sed -e 's/^/show create table '"$i"'./' hive_"$i"_tables_$FILETIME.txt | sed -e 's/$/;select"'"$LINE_SEPARATOR_MINI"'"; /' > hive_"$i"_tables_$FILETIME.sql
	sed -i '1s/^/select"'"$LINE_SEPARATOR_MINI"'";\n/' hive_"$i"_tables_$FILETIME.sql
	beeline --showHeader=false --outputformat="csv2" --silent -u "$JDBC_STRING" -f hive_"$i"_tables_$FILETIME.sql | tee hive_"$i"_DDLs_$FILETIME.txt
	sed -i $'s/[^[:print:]\t]//g' hive_"$i"_DDLs_$FILETIME.txt
	echo "Hive tables in database: $i" >> hive_"$i"_table_DDLs_$FILETIME.txt 
	cat hive_"$i"_tables_$FILETIME.txt >> hive_"$i"_table_DDLs_$FILETIME.txt
	echo "" >> hive_"$i"_table_DDLs_$FILETIME.txt
	echo "Hive DDLs for tables in database: $i" >> hive_"$i"_table_DDLs_$FILETIME.txt
	cat hive_"$i"_DDLs_$FILETIME.txt >> hive_"$i"_table_DDLs_$FILETIME.txt
	rm hive_"$i"_tables_$FILETIME.sql
	rm hive_"$i"_tables_$FILETIME.txt
	rm hive_"$i"_DDLs_$FILETIME.txt
done

