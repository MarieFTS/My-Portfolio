# ============================================================
# PROJECT: COVID-19 Data Analysis
# Author:  Marie Odile Fotso
# Tools:   Python, Pandas, Matplotlib, Seaborn
# Description: Analyzes global COVID-19 trends — cases, deaths,
#              vaccination rates, and recovery patterns.
# Dataset:     Our World in Data (owid-covid-data.csv)
#              https://github.com/owid/covid-19-data
# ============================================================

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mtick
import seaborn as sns
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# ── Style ──────────────────────────────────────────────────
plt.style.use('dark_background')
sns.set_palette("Blues_r")
BLUE   = '#1a73e8'
GREEN  = '#34d399'
RED    = '#f87171'
YELLOW = '#fbbf24'
MUTED  = '#7a90b0'


# ============================================================
# 1. LOAD & INSPECT DATA
# ============================================================

def load_data(filepath='owid-covid-data.csv'):
    """Load and perform initial inspection of the dataset."""
    df = pd.read_csv(filepath, parse_dates=['date'])
    print("=" * 55)
    print("DATASET OVERVIEW")
    print("=" * 55)
    print(f"Shape        : {df.shape[0]:,} rows × {df.shape[1]} columns")
    print(f"Date range   : {df['date'].min().date()} → {df['date'].max().date()}")
    print(f"Countries    : {df['location'].nunique()}")
    print(f"Missing vals : {df.isnull().sum().sum():,}")
    print()
    return df


# ============================================================
# 2. CLEAN & PREPARE
# ============================================================

def clean_data(df):
    """Clean dataset and engineer useful features."""
    # Drop aggregate rows (continents / World)
    agg_locations = ['World', 'Europe', 'Asia', 'Africa',
                     'North America', 'South America', 'Oceania',
                     'European Union', 'High income', 'Low income',
                     'Lower middle income', 'Upper middle income']
    df = df[~df['location'].isin(agg_locations)].copy()

    # Select key columns
    cols = [
        'location', 'continent', 'date',
        'total_cases', 'new_cases', 'total_deaths', 'new_deaths',
        'total_vaccinations', 'people_fully_vaccinated',
        'population', 'gdp_per_capita', 'median_age',
        'hospital_beds_per_thousand'
    ]
    df = df[[c for c in cols if c in df.columns]]

    # Fill numeric NaN with 0
    num_cols = df.select_dtypes(include='number').columns
    df[num_cols] = df[num_cols].fillna(0)

    # Derived metrics
    df['case_fatality_rate'] = np.where(
        df['total_cases'] > 0,
        (df['total_deaths'] / df['total_cases']) * 100, 0
    )
    df['cases_per_million'] = np.where(
        df['population'] > 0,
        (df['total_cases'] / df['population']) * 1_000_000, 0
    )
    df['vax_rate'] = np.where(
        df['population'] > 0,
        (df['people_fully_vaccinated'] / df['population']) * 100, 0
    )
    df['7day_avg_cases']  = (df.groupby('location')['new_cases']
                               .transform(lambda x: x.rolling(7, min_periods=1).mean()))
    df['7day_avg_deaths'] = (df.groupby('location')['new_deaths']
                               .transform(lambda x: x.rolling(7, min_periods=1).mean()))

    print(f"Clean dataset: {df.shape[0]:,} rows, {df['location'].nunique()} countries")
    return df


# ============================================================
# 3. GLOBAL SUMMARY
# ============================================================

def global_summary(df):
    """Print high-level global statistics."""
    latest = df.sort_values('date').groupby('location').last().reset_index()
    total_cases  = latest['total_cases'].sum()
    total_deaths = latest['total_deaths'].sum()
    total_vax    = latest['people_fully_vaccinated'].sum()
    cfr          = (total_deaths / total_cases * 100) if total_cases > 0 else 0

    print("=" * 55)
    print("GLOBAL SUMMARY (latest available data)")
    print("=" * 55)
    print(f"  Total Cases        : {total_cases:>15,.0f}")
    print(f"  Total Deaths       : {total_deaths:>15,.0f}")
    print(f"  Fully Vaccinated   : {total_vax:>15,.0f}")
    print(f"  Case Fatality Rate : {cfr:>14.2f}%")
    print()
    return latest


# ============================================================
# 4. TOP 10 CHARTS
# ============================================================

def plot_top10(latest, output='charts'):
    """Bar charts for top 10 countries by cases and deaths."""
    import os; os.makedirs(output, exist_ok=True)

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))
    fig.patch.set_facecolor('#0d0d0d')

    for ax in axes:
        ax.set_facecolor('#111827')

    # --- Cases ---
    top_cases = latest.nlargest(10, 'total_cases')[['location','total_cases']]
    axes[0].barh(top_cases['location'], top_cases['total_cases'] / 1e6,
                 color=BLUE, alpha=0.85)
    axes[0].set_title('Top 10 Countries by Total Cases', color='white', fontsize=13, pad=12)
    axes[0].set_xlabel('Cases (millions)', color=MUTED)
    axes[0].tick_params(colors='white')
    axes[0].invert_yaxis()

    # --- Deaths ---
    top_deaths = latest.nlargest(10, 'total_deaths')[['location','total_deaths']]
    axes[1].barh(top_deaths['location'], top_deaths['total_deaths'] / 1e3,
                 color=RED, alpha=0.85)
    axes[1].set_title('Top 10 Countries by Total Deaths', color='white', fontsize=13, pad=12)
    axes[1].set_xlabel('Deaths (thousands)', color=MUTED)
    axes[1].tick_params(colors='white')
    axes[1].invert_yaxis()

    plt.tight_layout()
    plt.savefig(f'{output}/top10_cases_deaths.png', dpi=150, bbox_inches='tight',
                facecolor='#0d0d0d')
    plt.close()
    print(f"  Saved: {output}/top10_cases_deaths.png")


# ============================================================
# 5. GLOBAL TREND OVER TIME
# ============================================================

def plot_global_trend(df, output='charts'):
    """Line chart of daily new cases (7-day avg) globally."""
    import os; os.makedirs(output, exist_ok=True)

    global_trend = (df.groupby('date')[['new_cases','new_deaths']]
                      .sum()
                      .reset_index())
    global_trend['7d_cases']  = global_trend['new_cases'].rolling(7).mean()
    global_trend['7d_deaths'] = global_trend['new_deaths'].rolling(7).mean()

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)
    fig.patch.set_facecolor('#0d0d0d')

    for ax in (ax1, ax2):
        ax.set_facecolor('#111827')
        ax.tick_params(colors='white')
        ax.spines['bottom'].set_color(MUTED)
        ax.spines['left'].set_color(MUTED)
        for s in ['top','right']: ax.spines[s].set_visible(False)

    ax1.fill_between(global_trend['date'], global_trend['7d_cases'],
                     alpha=0.3, color=BLUE)
    ax1.plot(global_trend['date'], global_trend['7d_cases'],
             color=BLUE, linewidth=1.5, label='7-day avg')
    ax1.set_title('Global Daily New Cases (7-day avg)', color='white', fontsize=12)
    ax1.set_ylabel('Cases', color=MUTED)
    ax1.yaxis.set_major_formatter(mtick.FuncFormatter(lambda x,_: f'{x/1e6:.1f}M'))

    ax2.fill_between(global_trend['date'], global_trend['7d_deaths'],
                     alpha=0.3, color=RED)
    ax2.plot(global_trend['date'], global_trend['7d_deaths'],
             color=RED, linewidth=1.5)
    ax2.set_title('Global Daily Deaths (7-day avg)', color='white', fontsize=12)
    ax2.set_ylabel('Deaths', color=MUTED)
    ax2.set_xlabel('Date', color=MUTED)

    plt.tight_layout()
    plt.savefig(f'{output}/global_trend.png', dpi=150, bbox_inches='tight',
                facecolor='#0d0d0d')
    plt.close()
    print(f"  Saved: {output}/global_trend.png")


# ============================================================
# 6. VACCINATION vs CASE FATALITY RATE
# ============================================================

def plot_vax_vs_cfr(latest, output='charts'):
    """Scatter: vaccination rate vs case fatality rate by continent."""
    import os; os.makedirs(output, exist_ok=True)

    data = latest[(latest['vax_rate'] > 0) & (latest['case_fatality_rate'] > 0)
                  & (latest['case_fatality_rate'] < 15)].copy()

    palette = {
        'Africa': '#f87171', 'Asia': '#fbbf24', 'Europe': '#1a73e8',
        'North America': '#34d399', 'Oceania': '#a78bfa',
        'South America': '#fb923c'
    }

    fig, ax = plt.subplots(figsize=(12, 7))
    fig.patch.set_facecolor('#0d0d0d')
    ax.set_facecolor('#111827')

    for continent, group in data.groupby('continent'):
        ax.scatter(group['vax_rate'], group['case_fatality_rate'],
                   label=continent, alpha=0.75, s=60,
                   color=palette.get(continent, '#fff'))

    # Trend line
    z = np.polyfit(data['vax_rate'], data['case_fatality_rate'], 1)
    p = np.poly1d(z)
    xs = np.linspace(data['vax_rate'].min(), data['vax_rate'].max(), 100)
    ax.plot(xs, p(xs), '--', color='white', alpha=0.4, linewidth=1.5)

    ax.set_title('Vaccination Rate vs Case Fatality Rate by Country',
                 color='white', fontsize=13, pad=14)
    ax.set_xlabel('Fully Vaccinated (%)', color=MUTED)
    ax.set_ylabel('Case Fatality Rate (%)', color=MUTED)
    ax.tick_params(colors='white')
    for s in ['top','right']: ax.spines[s].set_visible(False)
    ax.spines['bottom'].set_color(MUTED)
    ax.spines['left'].set_color(MUTED)
    ax.legend(facecolor='#0d0d0d', edgecolor=MUTED, labelcolor='white',
              fontsize=9, loc='upper right')

    plt.tight_layout()
    plt.savefig(f'{output}/vax_vs_cfr.png', dpi=150, bbox_inches='tight',
                facecolor='#0d0d0d')
    plt.close()
    print(f"  Saved: {output}/vax_vs_cfr.png")


# ============================================================
# 7. CONTINENT HEATMAP
# ============================================================

def plot_continent_heatmap(df, output='charts'):
    """Monthly heatmap of new cases per continent."""
    import os; os.makedirs(output, exist_ok=True)

    df2 = df.copy()
    df2['month'] = df2['date'].dt.to_period('M').astype(str)
    heat = (df2.groupby(['continent','month'])['new_cases']
               .sum().reset_index())
    heat_pivot = heat.pivot(index='continent', columns='month', values='new_cases')
    heat_pivot = heat_pivot.fillna(0)

    # Keep every 3rd month label to avoid clutter
    cols = heat_pivot.columns.tolist()
    xtick_labels = [c if i % 3 == 0 else '' for i, c in enumerate(cols)]

    fig, ax = plt.subplots(figsize=(18, 5))
    fig.patch.set_facecolor('#0d0d0d')
    sns.heatmap(heat_pivot / 1e6, ax=ax, cmap='Blues',
                linewidths=0.3, linecolor='#0d0d0d',
                cbar_kws={'label': 'Cases (millions)'})
    ax.set_xticklabels(xtick_labels, rotation=45, ha='right', color='white', fontsize=8)
    ax.set_yticklabels(ax.get_yticklabels(), color='white', fontsize=10)
    ax.set_title('Monthly COVID-19 Cases by Continent', color='white', fontsize=13, pad=12)
    ax.set_xlabel('Month', color=MUTED)
    ax.set_ylabel('', color=MUTED)

    plt.tight_layout()
    plt.savefig(f'{output}/continent_heatmap.png', dpi=150, bbox_inches='tight',
                facecolor='#0d0d0d')
    plt.close()
    print(f"  Saved: {output}/continent_heatmap.png")


# ============================================================
# 8. MAIN
# ============================================================

if __name__ == '__main__':
    print("\nCOVID-19 DATA ANALYSIS — Marie Odile Fotso\n")

    df      = load_data('owid-covid-data.csv')
    df      = clean_data(df)
    latest  = global_summary(df)

    print("Generating charts...")
    plot_top10(latest)
    plot_global_trend(df)
    plot_vax_vs_cfr(latest)
    plot_continent_heatmap(df)

    print("\nAll charts saved to charts/ folder.")
    print("Analysis complete.")
