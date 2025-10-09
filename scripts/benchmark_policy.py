#!/usr/bin/env python3
"""
Performance benchmark script for policy validation
"""

import json
import time
import statistics
from pathlib import Path
from validate_policy import RegoWASMValidator, load_test_scenarios

def benchmark_validation(validator, scenarios, iterations=100):
    """Benchmark validation performance"""
    print(f"🚀 Benchmarking with {iterations} iterations per scenario")
    print("=" * 60)
    
    results = {}
    
    for scenario in scenarios:
        test_name = scenario.get('_test_name', 'unknown')
        print(f"\n⏱️  Benchmarking: {test_name}")
        
        # Warm up
        for _ in range(10):
            try:
                validator.validate_input(scenario)
            except:
                pass
        
        # Actual benchmark
        times = []
        for i in range(iterations):
            start_time = time.perf_counter()
            try:
                validator.validate_input(scenario)
                end_time = time.perf_counter()
                times.append((end_time - start_time) * 1000)  # Convert to milliseconds
            except Exception as e:
                print(f"   ⚠️  Iteration {i+1} failed: {e}")
        
        if times:
            avg_time = statistics.mean(times)
            min_time = min(times)
            max_time = max(times)
            std_dev = statistics.stdev(times) if len(times) > 1 else 0
            
            results[test_name] = {
                'iterations': len(times),
                'avg_ms': avg_time,
                'min_ms': min_time,
                'max_ms': max_time,
                'std_dev_ms': std_dev,
                'throughput_per_sec': 1000 / avg_time if avg_time > 0 else 0
            }
            
            print(f"   ✅ Completed {len(times)} iterations")
            print(f"   📊 Average: {avg_time:.3f}ms")
            print(f"   📊 Min: {min_time:.3f}ms")
            print(f"   📊 Max: {max_time:.3f}ms")
            print(f"   📊 Std Dev: {std_dev:.3f}ms")
            print(f"   📊 Throughput: {1000/avg_time:.1f} validations/sec")
        else:
            print(f"   ❌ No successful iterations")
            results[test_name] = {'error': 'No successful iterations'}
    
    return results

def generate_benchmark_report(results):
    """Generate a comprehensive benchmark report"""
    print("\n" + "=" * 60)
    print("📊 BENCHMARK REPORT")
    print("=" * 60)
    
    successful_benchmarks = {k: v for k, v in results.items() if 'error' not in v}
    
    if not successful_benchmarks:
        print("❌ No successful benchmarks to report")
        return
    
    # Overall statistics
    all_avg_times = [v['avg_ms'] for v in successful_benchmarks.values()]
    overall_avg = statistics.mean(all_avg_times)
    overall_min = min(all_avg_times)
    overall_max = max(all_avg_times)
    
    print(f"Overall Performance:")
    print(f"   📊 Average across all scenarios: {overall_avg:.3f}ms")
    print(f"   📊 Best performance: {overall_min:.3f}ms")
    print(f"   📊 Worst performance: {overall_max:.3f}ms")
    
    # Ranking by performance
    print(f"\n🏆 Performance Ranking (by average time):")
    sorted_results = sorted(successful_benchmarks.items(), key=lambda x: x[1]['avg_ms'])
    
    for i, (name, data) in enumerate(sorted_results, 1):
        medal = "🥇" if i == 1 else "🥈" if i == 2 else "🥉" if i == 3 else "  "
        print(f"   {medal} {i}. {name}: {data['avg_ms']:.3f}ms ({data['throughput_per_sec']:.1f}/sec)")
    
    # Recommendations
    print(f"\n💡 Recommendations:")
    if overall_avg > 10:
        print("   ⚠️  Average validation time is above 10ms - consider optimization")
    elif overall_avg > 5:
        print("   ⚠️  Average validation time is above 5ms - monitor performance")
    else:
        print("   ✅ Performance is within acceptable limits")
    
    if max(all_avg_times) > overall_avg * 3:
        print("   ⚠️  High variance in performance - investigate outliers")
    
    return results

def main():
    """Main benchmark function"""
    print("🚀 Policy Validation Performance Benchmark")
    print("=" * 60)
    
    # Load test scenarios
    scenarios = load_test_scenarios()
    if not scenarios:
        print("❌ No test scenarios found")
        return 1
    
    # Initialize validator
    try:
        data_file = "policies/policy.json"
        with open(data_file, 'r') as f:
            policy_data = json.load(f)
        
        validator = RegoWASMValidator.__new__(RegoWASMValidator)
        validator.data = policy_data
        
    except Exception as e:
        print(f"❌ Failed to initialize validator: {e}")
        return 1
    
    # Run benchmarks
    try:
        results = benchmark_validation(validator, scenarios, iterations=100)
        generate_benchmark_report(results)
        
        # Save results to file
        output_file = "benchmark-results.json"
        with open(output_file, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\n💾 Results saved to {output_file}")
        
    except Exception as e:
        print(f"❌ Benchmark failed: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    import sys
    sys.exit(main())
