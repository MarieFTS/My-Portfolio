// ============================================================
// PROJECT: Java Data Analysis Tool
// Author:  Marie Odile Fotso
// Tools:   Java (Core)
// Description: A command-line tool that reads a CSV dataset
//              and performs descriptive statistics, filtering,
//              sorting, grouping, and frequency analysis.
// Usage:   java DataAnalysisTool data.csv
// ============================================================

import java.io.*;
import java.util.*;
import java.util.stream.*;

public class DataAnalysisTool {

    // ── Inner class to hold one row ──────────────────────────
    static class Row {
        String[] values;
        String[] headers;

        Row(String[] headers, String[] values) {
            this.headers = headers;
            this.values  = values;
        }

        String get(String column) {
            for (int i = 0; i < headers.length; i++) {
                if (headers[i].equalsIgnoreCase(column)) {
                    return i < values.length ? values[i].trim() : "";
                }
            }
            return "";
        }

        double getDouble(String column) {
            try { return Double.parseDouble(get(column)); }
            catch (NumberFormatException e) { return Double.NaN; }
        }
    }

    // ── Dataset ─────────────────────────────────────────────
    private String[]   headers;
    private List<Row>  rows = new ArrayList<>();
    private String     filename;

    // ── Load CSV ─────────────────────────────────────────────
    public void load(String filepath) throws IOException {
        this.filename = filepath;
        try (BufferedReader br = new BufferedReader(new FileReader(filepath))) {
            String line = br.readLine();
            if (line == null) throw new IOException("Empty file.");
            headers = line.split(",", -1);
            for (int i = 0; i < headers.length; i++)
                headers[i] = headers[i].trim().replaceAll("^\"|\"$", "");

            while ((line = br.readLine()) != null) {
                String[] vals = line.split(",", -1);
                rows.add(new Row(headers, vals));
            }
        }
        System.out.printf("Loaded: %s  (%,d rows, %d columns)%n%n",
                filename, rows.size(), headers.length);
    }

    // ── Overview ─────────────────────────────────────────────
    public void overview() {
        System.out.println("=".repeat(55));
        System.out.println("DATASET OVERVIEW");
        System.out.println("=".repeat(55));
        System.out.printf("  Rows    : %,d%n", rows.size());
        System.out.printf("  Columns : %d%n", headers.length);
        System.out.println("  Headers : " + String.join(", ", headers));
        System.out.println();

        // Sample — first 5 rows
        System.out.println("SAMPLE (first 5 rows):");
        System.out.println("-".repeat(55));
        for (int i = 0; i < Math.min(5, rows.size()); i++) {
            System.out.println("  " + String.join(" | ", rows.get(i).values));
        }
        System.out.println();
    }

    // ── Descriptive Statistics for a numeric column ──────────
    public void describe(String column) {
        List<Double> nums = rows.stream()
                .map(r -> r.getDouble(column))
                .filter(v -> !Double.isNaN(v))
                .sorted()
                .collect(Collectors.toList());

        if (nums.isEmpty()) {
            System.out.println("No numeric data in column: " + column);
            return;
        }

        double sum    = nums.stream().mapToDouble(Double::doubleValue).sum();
        double mean   = sum / nums.size();
        double min    = nums.get(0);
        double max    = nums.get(nums.size() - 1);
        double median = percentile(nums, 50);
        double q1     = percentile(nums, 25);
        double q3     = percentile(nums, 75);
        double stddev = stdDev(nums, mean);

        System.out.println("=".repeat(55));
        System.out.println("STATISTICS  →  " + column);
        System.out.println("=".repeat(55));
        System.out.printf("  Count   : %,d%n",   nums.size());
        System.out.printf("  Mean    : %10.2f%n", mean);
        System.out.printf("  Std Dev : %10.2f%n", stddev);
        System.out.printf("  Min     : %10.2f%n", min);
        System.out.printf("  Q1 (25%): %10.2f%n", q1);
        System.out.printf("  Median  : %10.2f%n", median);
        System.out.printf("  Q3 (75%): %10.2f%n", q3);
        System.out.printf("  Max     : %10.2f%n", max);
        System.out.printf("  Sum     : %10.2f%n", sum);
        System.out.println();
    }

    // ── Frequency count for a categorical column ─────────────
    public void frequency(String column, int topN) {
        Map<String, Long> freq = rows.stream()
                .collect(Collectors.groupingBy(
                        r -> r.get(column), Collectors.counting()));

        System.out.println("=".repeat(55));
        System.out.println("FREQUENCY  →  " + column + "  (top " + topN + ")");
        System.out.println("=".repeat(55));

        freq.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(topN)
                .forEach(e -> {
                    double pct = e.getValue() * 100.0 / rows.size();
                    System.out.printf("  %-25s  %6d  (%.1f%%)%n",
                            e.getKey(), e.getValue(), pct);
                });
        System.out.println();
    }

    // ── Filter rows ──────────────────────────────────────────
    public List<Row> filter(String column, String operator, String value) {
        double numVal = Double.NaN;
        try { numVal = Double.parseDouble(value); } catch (Exception ignored) {}

        final double fNumVal = numVal;
        List<Row> result = new ArrayList<>();
        for (Row r : rows) {
            String cellStr = r.get(column);
            double cellNum = r.getDouble(column);
            boolean match  = false;

            switch (operator) {
                case "="   : match = cellStr.equalsIgnoreCase(value); break;
                case "!="  : match = !cellStr.equalsIgnoreCase(value); break;
                case ">"   : match = !Double.isNaN(cellNum) && cellNum >  fNumVal; break;
                case ">="  : match = !Double.isNaN(cellNum) && cellNum >= fNumVal; break;
                case "<"   : match = !Double.isNaN(cellNum) && cellNum <  fNumVal; break;
                case "<="  : match = !Double.isNaN(cellNum) && cellNum <= fNumVal; break;
                case "contains": match = cellStr.toLowerCase()
                                         .contains(value.toLowerCase()); break;
            }
            if (match) result.add(r);
        }

        System.out.printf("Filter [%s %s %s] → %,d rows matched%n%n",
                column, operator, value, result.size());
        return result;
    }

    // ── Sort ─────────────────────────────────────────────────
    public List<Row> sort(String column, boolean ascending) {
        List<Row> sorted = new ArrayList<>(rows);
        sorted.sort((a, b) -> {
            double da = a.getDouble(column);
            double db = b.getDouble(column);
            int cmp;
            if (!Double.isNaN(da) && !Double.isNaN(db)) {
                cmp = Double.compare(da, db);
            } else {
                cmp = a.get(column).compareToIgnoreCase(b.get(column));
            }
            return ascending ? cmp : -cmp;
        });
        System.out.printf("Sorted by '%s' %s%n%n",
                column, ascending ? "ascending" : "descending");
        return sorted;
    }

    // ── Group & Aggregate ────────────────────────────────────
    public void groupBy(String groupCol, String valueCol, String aggFunc) {
        Map<String, List<Double>> groups = new LinkedHashMap<>();
        for (Row r : rows) {
            String key = r.get(groupCol);
            double val = r.getDouble(valueCol);
            if (!Double.isNaN(val)) {
                groups.computeIfAbsent(key, k -> new ArrayList<>()).add(val);
            }
        }

        System.out.println("=".repeat(55));
        System.out.printf("GROUP BY '%s'  |  %s(%s)%n",
                groupCol, aggFunc.toUpperCase(), valueCol);
        System.out.println("=".repeat(55));

        groups.entrySet().stream()
                .sorted((a, b) -> {
                    double va = aggregate(a.getValue(), aggFunc);
                    double vb = aggregate(b.getValue(), aggFunc);
                    return Double.compare(vb, va); // descending
                })
                .forEach(e -> {
                    double result = aggregate(e.getValue(), aggFunc);
                    System.out.printf("  %-25s  %10.2f%n", e.getKey(), result);
                });
        System.out.println();
    }

    // ── ASCII Bar Chart ──────────────────────────────────────
    public void barChart(String column, int topN) {
        Map<String, Long> freq = rows.stream()
                .collect(Collectors.groupingBy(
                        r -> r.get(column), Collectors.counting()));

        List<Map.Entry<String, Long>> top = freq.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(topN)
                .collect(Collectors.toList());

        long maxVal = top.get(0).getValue();
        int barWidth = 40;

        System.out.println("=".repeat(55));
        System.out.println("BAR CHART  →  " + column);
        System.out.println("=".repeat(55));
        top.forEach(e -> {
            int bars = (int) (e.getValue() * barWidth / maxVal);
            System.out.printf("  %-20s | %s %d%n",
                    truncate(e.getKey(), 20),
                    "█".repeat(bars),
                    e.getValue());
        });
        System.out.println();
    }

    // ── Helpers ──────────────────────────────────────────────
    private double percentile(List<Double> sorted, double p) {
        double idx = (p / 100.0) * (sorted.size() - 1);
        int lo = (int) Math.floor(idx);
        int hi = (int) Math.ceil(idx);
        return lo == hi ? sorted.get(lo)
                        : sorted.get(lo) + (idx - lo) * (sorted.get(hi) - sorted.get(lo));
    }

    private double stdDev(List<Double> nums, double mean) {
        double variance = nums.stream()
                .mapToDouble(v -> Math.pow(v - mean, 2))
                .average().orElse(0.0);
        return Math.sqrt(variance);
    }

    private double aggregate(List<Double> vals, String func) {
        return switch (func.toLowerCase()) {
            case "sum"   -> vals.stream().mapToDouble(Double::doubleValue).sum();
            case "avg"   -> vals.stream().mapToDouble(Double::doubleValue).average().orElse(0);
            case "count" -> (double) vals.size();
            case "max"   -> vals.stream().mapToDouble(Double::doubleValue).max().orElse(0);
            case "min"   -> vals.stream().mapToDouble(Double::doubleValue).min().orElse(0);
            default      -> 0;
        };
    }

    private String truncate(String s, int max) {
        return s.length() <= max ? s : s.substring(0, max - 1) + "…";
    }

    // ============================================================
    // MAIN — Demo with a sample sales CSV
    // ============================================================
    public static void main(String[] args) throws IOException {
        DataAnalysisTool tool = new DataAnalysisTool();

        String file = args.length > 0 ? args[0] : "data.csv";
        tool.load(file);
        tool.overview();

        // Describe numeric columns
        tool.describe("Amount");
        tool.describe("Quantity");

        // Frequency analysis
        tool.frequency("Category", 10);
        tool.frequency("Region", 10);

        // Filter: orders above $500
        List<Row> highValue = tool.filter("Amount", ">", "500");

        // Group by Region, sum of Amount
        tool.groupBy("Region", "Amount", "sum");
        tool.groupBy("Category", "Amount", "avg");

        // Sort by Amount descending (top 10 shown)
        List<Row> sorted = tool.sort("Amount", false);
        System.out.println("TOP 10 HIGHEST VALUE ORDERS:");
        System.out.println("-".repeat(55));
        sorted.stream().limit(10).forEach(r ->
                System.out.println("  " + String.join(" | ", r.values)));
        System.out.println();

        // ASCII chart
        tool.barChart("Category", 8);

        System.out.println("Analysis complete.");
    }
}
