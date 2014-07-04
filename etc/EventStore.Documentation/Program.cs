﻿using EventStore.Common.Options;
using PowerArgs;
using System;
using System.IO;
using System.Linq;
using System.Reflection;

namespace EventStore.Documentation
{
    class Program
    {
        static void Main(string[] args)
        {
            var documentation = String.Empty;
            foreach (var assemblyFilePath in new DirectoryInfo(".").GetFiles().Where(x => x.Name.Contains("EventStore") && x.Name.EndsWith("exe")))
            {
                var assembly = Assembly.LoadFrom(assemblyFilePath.FullName);
                var optionTypes = assembly.GetTypes().Where(x => typeof(IOptions).IsAssignableFrom(x));

                foreach (var optionType in optionTypes)
                {
                    var optionConstructor = optionType.GetConstructor(new Type[]{});
                    var options = optionConstructor.Invoke(null);
                    var optionDocumentation = String.Format("<h3>{0}</h3>", options.GetType().Name);
                    optionDocumentation += "<table>";
                    optionDocumentation += @"<tr>
	                <th>Parameter</th>
	                <th>Environment *(all prefixed with EVENTSTORE_)*</th>
	                <th>Json</th>
	                <th>Description</th>
	                <th>Default</th>
                    </tr>";
                    var properties = options.GetType().GetProperties();
                    var argumentsDefinition = new CommandLineArgumentsDefinition(optionType);
                    foreach (var property in properties)
                    {
                        var parameterRow = "<tr>";
                        var parameterDefinition = argumentsDefinition.Arguments.First(x => ((PropertyInfo)x.Source).Name == property.Name);
                        var parameterUsageFormat = "-{0}";
                        var parameterUsage = String.Empty;
                        foreach (var alias in parameterDefinition.Aliases.Reverse())
                        {
                            parameterUsage += String.Format(parameterUsageFormat, alias);
                            parameterUsageFormat = "<br/>--{0}=VALUE";
                        }
                        parameterRow += String.Format("<td>{0}</td>", parameterUsage);
                        parameterRow += String.Format("<td>{0}</td>", EnvironmentVariableNameProvider.GetName("EVENTSTORE_", property.Name.ToUpper()));
                        parameterRow += String.Format("<td>{0}</td>", FirstCharToLower(property.Name));
                        parameterRow += String.Format("<td>{0}</td>", property.Attr<ArgDescription>().Description);
                        parameterRow += String.Format("<td>{0}</td>", GetValues(property.GetValue(options)));
                        parameterRow += "</tr>";
                        optionDocumentation += parameterRow;
                    }
                    optionDocumentation += "</table>";
                    documentation += optionDocumentation;
                }
            }
            File.WriteAllText("documentation.html", documentation);
        }

        public static string GetValues(object value)
        {
            if(value is Array)
            {
                var values = String.Empty;
                foreach (var val in (Array)value)
                {
                    values += val + ",";
                }
                return values.Length > 1 ? values.Substring(0, values.Length - 1) : "n/a";
            }
            return value.ToString();
        }

        public static string FirstCharToLower(string input)
        {
            if (String.IsNullOrEmpty(input))
                throw new ArgumentException("ARGH!");
            return input.First().ToString().ToLower() + String.Join("", input.Skip(1));
        }
    }
}