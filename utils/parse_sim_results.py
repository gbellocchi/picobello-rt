#!/usr/bin/env python3
"""
Script to parse ModelSim/QuestaSim simulation results from picobello testbench.
Extracts test performance metrics and outputs them in a structured format.
"""

import re
import sys
import csv
from typing import List, Dict, Optional, Set
from dataclasses import dataclass
from pathlib import Path

class SimResultsParser:
    """Parser for simulation results from picobello testbench."""
    
    def __init__(self, target_metrics: Optional[Set[str]] = None):
        # Regex patterns for parsing different parts of the log
        # Test header format: "# [204990000ns] Test #0"
        self.test_header_pattern = re.compile(r'^#\s*\[(\d+)ns\]\s*Test\s*#(\d+)$')
        
        # Generic pattern to match any metric line: "#  - MetricName: value"
        self.generic_metric_pattern = re.compile(r'^#\s*-\s*([^:]+):\s*(.+)$')
        
        # Set of metrics to extract (if None, extract all found metrics)
        self.target_metrics = target_metrics
        
    def parse_file(self, filename: str) -> List[Dict[str, any]]:
        """Parse the simulation log file and extract test results."""
        results = []
        current_test = None
        current_metrics = {}
        all_metric_names = set()  # Track all metric names found
        
        try:
            with open(filename, 'r') as file:
                for line_num, line in enumerate(file, 1):
                    line = line.strip()
                    
                    # Skip empty lines
                    if not line:
                        continue
                    
                    # Check for test header (commented): "# [204990000ns] Test #0"
                    header_match = self.test_header_pattern.match(line)
                    if header_match:
                        # Save previous test if exists
                        if current_test is not None:
                            test_result = self._create_test_result(current_test[0], current_test[1], current_metrics)
                            if test_result:
                                results.append(test_result)
                        
                        # Start new test
                        timestamp_ns = int(header_match.group(1))
                        test_num = int(header_match.group(2))
                        current_test = (test_num, timestamp_ns)
                        current_metrics = {}
                        continue
                    
                    # Check for metrics using generic pattern (also commented): "#  - MetricName: value"
                    if current_test is not None:
                        metric_match = self.generic_metric_pattern.match(line)
                        if metric_match:
                            metric_name = metric_match.group(1).strip()
                            metric_value_str = metric_match.group(2).strip()
                            
                            # Convert metric name to a clean variable name
                            clean_name = self._clean_metric_name(metric_name)
                            all_metric_names.add(clean_name)
                            
                            # Only extract if it's in target metrics or if no target specified
                            if self.target_metrics is None or clean_name in self.target_metrics:
                                # Try to convert to appropriate type
                                metric_value = self._convert_value(metric_value_str)
                                current_metrics[clean_name] = {
                                    'original_name': metric_name,
                                    'value': metric_value,
                                    'raw_value': metric_value_str
                                }
                
                # Don't forget the last test
                if current_test is not None:
                    test_result = self._create_test_result(current_test[0], current_test[1], current_metrics)
                    if test_result:
                        results.append(test_result)
                        
        except FileNotFoundError:
            print(f"Error: File '{filename}' not found.")
            return []
        except Exception as e:
            print(f"Error parsing file: {e}")
            return []
        
        # Print found metrics if no target was specified
        if self.target_metrics is None and all_metric_names:
            print(f"Found {len(all_metric_names)} unique metrics:")
            for name in sorted(all_metric_names):
                print(f"  - {name}")
            print()
            
        return results
    
    def _clean_metric_name(self, name: str) -> str:
        """Convert metric name to a clean, Excel-friendly CamelCase variable name."""
        # Remove special characters but keep spaces and brackets
        clean = re.sub(r'[^\w\s\[\]]', '', name)
        # Replace multiple spaces with single space
        clean = re.sub(r'\s+', ' ', clean)
        # Convert [0] to 0, [NCl-1] to NCl1, etc. (remove brackets and convert dash to nothing)
        clean = re.sub(r'\[([^\]]+)\]', lambda m: m.group(1).replace('-', ''), clean)
        # Split on spaces and underscores, then create CamelCase
        words = re.split(r'[\s_]+', clean)
        
        # General approach: capitalize each word and preserve existing case patterns
        result_words = []
        for word in words:
            if not word:
                continue
            
            # If word is already mixed case (e.g., NCl, XMem), preserve it
            if any(c.isupper() for c in word[1:]) and any(c.islower() for c in word):
                result_words.append(word)
            # If word is all uppercase and length > 1, keep it uppercase (likely acronym)
            elif word.isupper() and len(word) > 1:
                result_words.append(word)
            # Otherwise, capitalize first letter
            else:
                result_words.append(word.capitalize())
        
        camel_case = ''.join(result_words)
        return camel_case
    
    def _convert_value(self, value_str: str) -> any:
        """Convert string value to appropriate type."""
        value_str = value_str.strip()
        
        # Try to convert to int first
        try:
            return int(value_str)
        except ValueError:
            pass
        
        # Try to convert to float
        try:
            return float(value_str)
        except ValueError:
            pass
        
        # Return as string if conversion fails
        return value_str
    
    def _create_test_result(self, test_num: int, timestamp_ns: int, metrics: Dict[str, Dict]) -> Optional[Dict[str, any]]:
        """Create a test result dictionary from parsed metrics."""
        try:
            result = {
                'TestNum': test_num,
                'TimestampNs': timestamp_ns
            }
            
            # Add all extracted metrics
            for metric_name, metric_data in metrics.items():
                result[metric_name] = metric_data['value']
                # Also add original name as metadata if needed
                result[f"{metric_name}OriginalName"] = metric_data['original_name']
            
            return result
        except Exception as e:
            print(f"Error creating test result for test {test_num}: {e}")
            return None

def print_summary(results: List[Dict[str, any]]):
    """Print a summary of the parsed results."""
    if not results:
        print("No test results found.")
        return
    
    print(f"\nParsed {len(results)} test results:")
    print("=" * 100)
    
    # Get all metric keys (excluding metadata)
    if results:
        metric_keys = [k for k in results[0].keys() 
                      if not k.endswith('OriginalName') and k not in ['TestNum', 'TimestampNs']]
        
        # Print header
        header = f"{'Test#':<6} {'Timestamp':<12}"
        for key in metric_keys[:8]:  # Limit to first 8 metrics for readability
            header += f" {key:<12}"
        print(header)
        print("-" * 100)
        
        # Print data
        for result in results:
            row = f"{result.get('TestNum', 'N/A'):<6} {result.get('TimestampNs', 0):<12}"
            for key in metric_keys[:8]:
                value = result.get(key, 'N/A')
                row += f" {str(value):<12}"
            print(row)

def save_to_csv(results: List[Dict[str, any]], filename: str, include_metadata: bool = False):
    """Save results to a CSV file."""
    if not results:
        print("No results to save.")
        return
    
    try:
        # Get all fieldnames
        all_fields = set()
        for result in results:
            all_fields.update(result.keys())
        
        # Filter out metadata fields if not requested
        if not include_metadata:
            fieldnames = [f for f in all_fields if not f.endswith('OriginalName')]
        else:
            fieldnames = list(all_fields)
        
        # Sort fieldnames with logical ordering for better Excel readability
        priority_fields = ['TestNum', 'TimestampNs']
        metric_fields = [f for f in fieldnames if f not in priority_fields]
        
        # Custom ordering for common performance metrics (not too application-specific)
        end_fields = []
        if 'NOps' in metric_fields:
            end_fields.append('NOps')
            metric_fields.remove('NOps')
        if 'ExecTime' in metric_fields:
            end_fields.append('ExecTime')
            metric_fields.remove('ExecTime')
        
        metric_fields.sort()  # Alphabetical for remaining metrics
        fieldnames = priority_fields + metric_fields + end_fields
        
        with open(filename, 'w', newline='') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            for result in results:
                # Filter the result dict to only include desired fields
                filtered_result = {k: v for k, v in result.items() if k in fieldnames}
                writer.writerow(filtered_result)
        
        print(f"Results saved to '{filename}' with {len(fieldnames)} columns")
        print(f"Columns: {', '.join(fieldnames[:10])}{'...' if len(fieldnames) > 10 else ''}")
    except Exception as e:
        print(f"Error saving to CSV: {e}")

def main():
    """Main function."""
    if len(sys.argv) < 2:
        print("Usage: python parse_sim_results.py <log_file> [options]")
        print("Options:")
        print("  --csv <filename>       Save results to CSV file")
        print("  --metrics <m1,m2,m3>   Only extract specified metrics (comma-separated)")
        print("  --include-metadata     Include original metric names in CSV output")
        print("  --summary              Show summary table")
        print()
        print("Examples:")
        print("  python parse_sim_results.py log.txt --csv results.csv")
        print("  python parse_sim_results.py log.txt --metrics nops,exec_time --csv results.csv")
        print("  python parse_sim_results.py log.txt --summary")
        sys.exit(1)
    
    filename = sys.argv[1]
    
    # Parse command line options
    save_csv = False
    csv_filename = ""
    show_summary = "--summary" in sys.argv
    include_metadata = "--include-metadata" in sys.argv
    target_metrics = None
    
    if "--csv" in sys.argv:
        csv_index = sys.argv.index("--csv")
        if csv_index + 1 < len(sys.argv):
            csv_filename = sys.argv[csv_index + 1]
            save_csv = True
        else:
            print("Error: --csv option requires a filename")
            sys.exit(1)
    
    if "--metrics" in sys.argv:
        metrics_index = sys.argv.index("--metrics")
        if metrics_index + 1 < len(sys.argv):
            metrics_str = sys.argv[metrics_index + 1]
            target_metrics = set(m.strip().lower() for m in metrics_str.split(','))
            print(f"Targeting metrics: {', '.join(sorted(target_metrics))}")
        else:
            print("Error: --metrics option requires a comma-separated list")
            sys.exit(1)
    
    # Parse the file
    parser = SimResultsParser(target_metrics=target_metrics)
    results = parser.parse_file(filename)
    
    if not results:
        print("No valid test results found in the file.")
        sys.exit(1)
    
    # Display results based on options
    if show_summary or (not save_csv):
        print_summary(results)
    
    if save_csv:
        save_to_csv(results, csv_filename, include_metadata=include_metadata)

if __name__ == "__main__":
    main()
