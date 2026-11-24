import argparse
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

class benchmark:
    def __init__(self, name):
        self.algo_name = name
        self.input_size = []
        self.element_size = []
        self.time = []

    def add_values(self, values):
        self.input_size.append(values[0])
        self.element_size.append(values[1])
        self.time.append(values[2])

    def get_input_size(self):
        return self.input_size[0]

    def get_element_size(self):
        return self.element_size[0]

    def get_time(self):
        return np.median(self.time, axis=0)

def plot(data, args):
    for benchmark in data:
        if args.sort and "SHUFFLE" in benchmark.algo_name:
            continue

        if args.shuffle and "SORT" in benchmark.algo_name:
            continue

        plt.plot(benchmark.get_element_size() if args.e else benchmark.get_input_size() , benchmark.get_time(), marker="o", markersize=3, label=benchmark.algo_name)

    plt.xlabel("Element size (bytes)" if args.e else "Number of elements")
    plt.ylabel("Running time (seconds)")
    plt.title("Benchmark results")
    plt.xscale("log")
    plt.yscale("log")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.show()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", nargs="?", type=Path, default=Path("./"), help="Directory containing benchmark files")
    parser.add_argument("-e", action="store_true", help="Plot element size instead of input size")
    parser.add_argument("--shuffle", action="store_true", help="Only plot shuffling algorithms")
    parser.add_argument("--sort", action="store_true", help="Only plot sorting algorithms")
    args = parser.parse_args()

    algo_benchmarks = {} # store benchmarks for each algorithm

    files = args.directory.glob("*run?.out") # grab all .out files (skip warmup runs)

    for file in files:
        name = file.name.partition("_")[0] # extract algo name

        # add a new object if we haven't seen the algo
        if algo_benchmarks.get(name) is None:
            algo_benchmarks[name] = benchmark(name)

        # read out measurements and store in benchmark object
        algo_benchmarks[name].add_values(np.loadtxt(file, unpack=True))

    plot(algo_benchmarks.values(), args)
    

main()
