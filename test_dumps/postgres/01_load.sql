-- Investment Portfolio Database
-- Comprehensive schema for investment tracking and portfolio management
-- Note: Database 'test' is already created by Docker, so we skip DROP/CREATE

\c test;

-- Asset Categories
DROP TABLE IF EXISTS asset_categories CASCADE;
CREATE TABLE asset_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Market Data
DROP TABLE IF EXISTS market_data CASCADE;
CREATE TABLE market_data (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    company_name VARCHAR(200),
    sector VARCHAR(100),
    asset_category_id INTEGER REFERENCES asset_categories(id),
    current_price DECIMAL(12, 4),
    previous_close DECIMAL(12, 4),
    market_cap BIGINT,
    volume INTEGER,
    pe_ratio DECIMAL(6, 2),
    dividend_yield DECIMAL(6, 4),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users/Investors
DROP TABLE IF EXISTS investors CASCADE;
CREATE TABLE investors (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    risk_tolerance VARCHAR(20) CHECK (risk_tolerance IN ('conservative', 'moderate', 'aggressive')),
    investment_experience VARCHAR(20) CHECK (investment_experience IN ('beginner', 'intermediate', 'advanced')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Portfolios
DROP TABLE IF EXISTS portfolios CASCADE;
CREATE TABLE portfolios (
    id SERIAL PRIMARY KEY,
    investor_id INTEGER NOT NULL REFERENCES investors(id),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    target_allocation JSONB, -- Target asset allocation percentages
    total_value DECIMAL(15, 2) DEFAULT 0,
    cash_balance DECIMAL(12, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_rebalanced TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Portfolio Holdings/Positions
DROP TABLE IF EXISTS positions CASCADE;
CREATE TABLE positions (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id),
    symbol VARCHAR(20) NOT NULL,
    quantity DECIMAL(12, 6) NOT NULL,
    avg_cost_basis DECIMAL(12, 4) NOT NULL, -- Average purchase price
    current_value DECIMAL(12, 2),
    unrealized_gain_loss DECIMAL(12, 2),
    position_type VARCHAR(20) DEFAULT 'long' CHECK (position_type IN ('long', 'short')),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trading Transactions
DROP TABLE IF EXISTS trades CASCADE;
CREATE TABLE trades (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id),
    symbol VARCHAR(20) NOT NULL,
    trade_type VARCHAR(10) NOT NULL CHECK (trade_type IN ('BUY', 'SELL')),
    quantity DECIMAL(12, 6) NOT NULL,
    price DECIMAL(12, 4) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL,
    fees DECIMAL(8, 2) DEFAULT 0,
    trade_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    settlement_date DATE,
    status VARCHAR(20) DEFAULT 'executed' CHECK (status IN ('pending', 'executed', 'cancelled', 'failed')),
    notes TEXT
);

-- Dividend Payments
DROP TABLE IF EXISTS dividend_payments CASCADE;
CREATE TABLE dividend_payments (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id),
    symbol VARCHAR(20) NOT NULL,
    shares_held DECIMAL(12, 6) NOT NULL,
    dividend_per_share DECIMAL(8, 4) NOT NULL,
    total_dividend DECIMAL(10, 2) NOT NULL,
    ex_dividend_date DATE,
    payment_date DATE,
    status VARCHAR(20) DEFAULT 'paid' CHECK (status IN ('announced', 'ex_dividend', 'paid'))
);

-- Performance Tracking
DROP TABLE IF EXISTS portfolio_performance CASCADE;
CREATE TABLE portfolio_performance (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id),
    date DATE NOT NULL,
    total_value DECIMAL(15, 2) NOT NULL,
    daily_return_pct DECIMAL(8, 4),
    cumulative_return_pct DECIMAL(8, 4),
    benchmark_return_pct DECIMAL(8, 4), -- S&P 500 or other benchmark
    cash_balance DECIMAL(12, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(portfolio_id, date)
);

-- Risk Metrics
DROP TABLE IF EXISTS risk_metrics CASCADE;
CREATE TABLE risk_metrics (
    id SERIAL PRIMARY KEY,
    portfolio_id INTEGER NOT NULL REFERENCES portfolios(id),
    calculation_date DATE NOT NULL,
    volatility_30d DECIMAL(8, 4), -- 30-day volatility
    beta DECIMAL(6, 4), -- Portfolio beta vs market
    sharpe_ratio DECIMAL(6, 4),
    max_drawdown DECIMAL(8, 4), -- Maximum loss from peak
    var_95 DECIMAL(10, 2), -- Value at Risk 95% confidence
    sector_concentration JSONB, -- Sector allocation percentages
    top_10_concentration DECIMAL(6, 4), -- % in top 10 holdings
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert Sample Data

-- Asset Categories
INSERT INTO asset_categories (name, description) VALUES
('Equity', 'Stock market investments including individual stocks and equity funds'),
('Fixed Income', 'Bonds, treasury securities, and other debt instruments'),
('Real Estate', 'REITs and real estate investment trusts'),
('Commodities', 'Gold, silver, oil, and other commodity investments'),
('Cash', 'Money market funds, savings, and cash equivalents'),
('Cryptocurrency', 'Digital assets and cryptocurrency investments');

-- Market Data (Current as of recent date)
INSERT INTO market_data (symbol, company_name, sector, asset_category_id, current_price, previous_close, market_cap, volume, pe_ratio, dividend_yield, last_updated) VALUES
('AAPL', 'Apple Inc.', 'Technology', 1, 189.85, 188.50, 2958000000000, 45234567, 28.5, 0.0052, '2025-08-27 16:00:00'),
('MSFT', 'Microsoft Corporation', 'Technology', 1, 423.15, 421.80, 3142000000000, 23456789, 32.1, 0.0071, '2025-08-27 16:00:00'),
('GOOGL', 'Alphabet Inc.', 'Technology', 1, 134.25, 135.10, 1678000000000, 34567890, 24.8, 0.0000, '2025-08-27 16:00:00'),
('AMZN', 'Amazon.com Inc.', 'Consumer Discretionary', 1, 142.30, 141.75, 1489000000000, 28901234, 45.2, 0.0000, '2025-08-27 16:00:00'),
('TSLA', 'Tesla Inc.', 'Consumer Discretionary', 1, 201.56, 198.25, 642000000000, 67890123, 48.9, 0.0000, '2025-08-27 16:00:00'),
('NVDA', 'NVIDIA Corporation', 'Technology', 1, 892.45, 885.20, 2201000000000, 45123456, 67.3, 0.0036, '2025-08-27 16:00:00'),
('JPM', 'JPMorgan Chase & Co.', 'Financials', 1, 178.92, 179.45, 521000000000, 12345678, 11.8, 0.0289, '2025-08-27 16:00:00'),
('JNJ', 'Johnson & Johnson', 'Healthcare', 1, 162.87, 163.25, 427000000000, 8901234, 16.2, 0.0298, '2025-08-27 16:00:00'),
('V', 'Visa Inc.', 'Information Technology', 1, 267.34, 265.80, 567000000000, 6789012, 33.4, 0.0078, '2025-08-27 16:00:00'),
('WMT', 'Walmart Inc.', 'Consumer Staples', 1, 161.45, 160.90, 435000000000, 9012345, 26.8, 0.0248, '2025-08-27 16:00:00'),
('SPY', 'SPDR S&P 500 ETF Trust', 'ETF', 1, 549.23, 547.89, 502000000000, 78901234, 0.0, 0.0133, '2025-08-27 16:00:00'),
('QQQ', 'Invesco QQQ Trust', 'ETF', 1, 467.82, 465.35, 201000000000, 34567891, 0.0, 0.0053, '2025-08-27 16:00:00'),
('TLT', 'iShares 20+ Year Treasury Bond ETF', 'ETF', 2, 89.56, 90.12, 15600000000, 12345679, 0.0, 0.0285, '2025-08-27 16:00:00'),
('GLD', 'SPDR Gold Shares', 'ETF', 4, 201.34, 200.85, 73400000000, 5678901, 0.0, 0.0000, '2025-08-27 16:00:00'),
('VTI', 'Vanguard Total Stock Market ETF', 'ETF', 1, 265.47, 264.12, 412000000000, 23456789, 0.0, 0.0132, '2025-08-27 16:00:00');

-- Investors
INSERT INTO investors (first_name, last_name, email, risk_tolerance, investment_experience, created_at, last_login) VALUES
('Sarah', 'Johnson', 'sarah.johnson@email.com', 'moderate', 'intermediate', '2023-01-15 09:30:00', '2025-08-27 08:15:00'),
('Michael', 'Chen', 'michael.chen@email.com', 'aggressive', 'advanced', '2022-06-20 14:45:00', '2025-08-27 07:30:00'),
('Emily', 'Rodriguez', 'emily.rodriguez@email.com', 'conservative', 'beginner', '2023-03-10 11:20:00', '2025-08-26 19:45:00'),
('David', 'Thompson', 'david.thompson@email.com', 'moderate', 'intermediate', '2022-11-05 16:30:00', '2025-08-27 06:50:00'),
('Lisa', 'Anderson', 'lisa.anderson@email.com', 'aggressive', 'advanced', '2023-07-12 13:15:00', '2025-08-27 09:10:00'),
('Robert', 'Wilson', 'robert.wilson@email.com', 'conservative', 'intermediate', '2023-02-28 10:45:00', '2025-08-25 20:30:00'),
('Jennifer', 'Brown', 'jennifer.brown@email.com', 'moderate', 'advanced', '2022-09-18 12:00:00', '2025-08-27 08:45:00'),
('Mark', 'Davis', 'mark.davis@email.com', 'aggressive', 'intermediate', '2023-05-03 15:20:00', '2025-08-26 22:15:00');

-- Portfolios
INSERT INTO portfolios (investor_id, name, description, target_allocation, total_value, cash_balance, created_at, last_rebalanced, is_active) VALUES
(1, 'Retirement Portfolio', 'Long-term retirement savings with balanced allocation', '{"equity": 60, "fixed_income": 30, "cash": 10}', 125000.00, 5000.00, '2023-01-20 10:00:00', '2025-08-01 09:00:00', TRUE),
(2, 'Growth Portfolio', 'Aggressive growth focused on technology and emerging markets', '{"equity": 85, "fixed_income": 5, "alternatives": 10}', 245000.00, 12000.00, '2022-06-25 11:30:00', '2025-07-15 14:30:00', TRUE),
(3, 'Conservative Income', 'Income focused portfolio with dividend stocks and bonds', '{"equity": 40, "fixed_income": 50, "cash": 10}', 75000.00, 8000.00, '2023-03-15 09:45:00', '2025-06-30 16:15:00', TRUE),
(4, 'Balanced Growth', 'Moderate risk portfolio with diversified holdings', '{"equity": 70, "fixed_income": 25, "cash": 5}', 180000.00, 3500.00, '2022-11-10 13:20:00', '2025-08-10 11:45:00', TRUE),
(5, 'Tech Focus', 'Technology sector concentrated portfolio', '{"equity": 95, "cash": 5}', 320000.00, 16000.00, '2023-07-18 08:15:00', '2025-07-25 10:30:00', TRUE),
(6, 'Dividend Income', 'Dividend focused portfolio for current income', '{"equity": 60, "fixed_income": 35, "cash": 5}', 95000.00, 2500.00, '2023-03-05 14:00:00', '2025-08-05 09:30:00', TRUE),
(7, 'Index Fund Portfolio', 'Low-cost index fund based portfolio', '{"equity": 80, "fixed_income": 15, "cash": 5}', 210000.00, 8500.00, '2022-09-25 10:30:00', '2025-07-20 15:45:00', TRUE),
(8, 'Speculative Growth', 'High risk, high reward growth portfolio', '{"equity": 90, "alternatives": 8, "cash": 2}', 85000.00, 1700.00, '2023-05-08 12:45:00', '2025-08-12 08:20:00', TRUE);

-- Positions (Current holdings)
INSERT INTO positions (portfolio_id, symbol, quantity, avg_cost_basis, current_value, unrealized_gain_loss, last_updated) VALUES
-- Sarah's Retirement Portfolio
(1, 'SPY', 45.0, 485.20, 24715.35, 3825.35, '2025-08-27 16:00:00'),
(1, 'VTI', 25.0, 245.80, 6636.75, 1489.75, '2025-08-27 16:00:00'),
(1, 'TLT', 150.0, 95.30, 13434.00, -1861.00, '2025-08-27 16:00:00'),
(1, 'AAPL', 100.0, 175.50, 18985.00, 1435.00, '2025-08-27 16:00:00'),
-- Michael's Growth Portfolio  
(2, 'NVDA', 75.0, 750.25, 66933.75, 10683.75, '2025-08-27 16:00:00'),
(2, 'TSLA', 120.0, 185.40, 24187.20, 1950.20, '2025-08-27 16:00:00'),
(2, 'GOOGL', 200.0, 125.80, 26850.00, 1750.00, '2025-08-27 16:00:00'),
(2, 'AMZN', 150.0, 135.20, 21345.00, 1065.00, '2025-08-27 16:00:00'),
(2, 'QQQ', 80.0, 445.75, 37425.60, 2720.60, '2025-08-27 16:00:00'),
-- Emily's Conservative Portfolio
(3, 'JNJ', 80.0, 158.90, 13029.60, 317.60, '2025-08-27 16:00:00'),
(3, 'WMT', 60.0, 155.20, 9687.00, 375.00, '2025-08-27 16:00:00'),
(3, 'JPM', 45.0, 172.85, 8051.40, 281.15, '2025-08-27 16:00:00'),
(3, 'TLT', 200.0, 92.45, 17912.00, -578.00, '2025-08-27 16:00:00'),
-- David's Balanced Portfolio
(4, 'SPY', 80.0, 475.60, 43938.40, 5878.40, '2025-08-27 16:00:00'),
(4, 'MSFT', 45.0, 395.80, 19041.75, 1227.75, '2025-08-27 16:00:00'),
(4, 'V', 35.0, 255.90, 9356.90, 410.40, '2025-08-27 16:00:00'),
(4, 'TLT', 100.0, 93.25, 8956.00, -369.00, '2025-08-27 16:00:00'),
-- Lisa's Tech Focus
(5, 'AAPL', 250.0, 165.30, 47462.50, 6087.50, '2025-08-27 16:00:00'),
(5, 'MSFT', 120.0, 385.20, 50778.00, 4560.00, '2025-08-27 16:00:00'),
(5, 'NVDA', 45.0, 825.60, 40160.25, 3015.25, '2025-08-27 16:00:00'),
(5, 'GOOGL', 180.0, 130.85, 24165.00, 612.00, '2025-08-27 16:00:00'),
-- Additional positions with large losses (> $10,000) for alert testing
(6, 'AAPL', 200.0, 220.50, 37970.00, -6130.00, '2025-08-27 16:00:00'), -- Loss > $10k
(6, 'MSFT', 80.0, 480.25, 33852.00, -4568.00, '2025-08-27 16:00:00'),
(7, 'TSLA', 100.0, 275.30, 20156.00, -7374.00, '2025-08-27 16:00:00'),
(8, 'NVDA', 30.0, 950.80, 26773.50, -1750.50, '2025-08-27 16:00:00'),
(2, 'AAPL', 150.0, 250.85, 28477.50, -9150.00, '2025-08-27 16:00:00'),
(4, 'AMZN', 75.0, 185.60, 10672.50, -3245.00, '2025-08-27 16:00:00'),
-- Massive loss positions to trigger alerts
(1, 'TSLA', 80.0, 315.75, 16124.80, -9115.20, '2025-08-27 16:00:00'), -- Loss > $10k
(3, 'NVDA', 25.0, 1050.20, 22311.25, -3933.75, '2025-08-27 16:00:00'),
(7, 'GOOGL', 120.0, 175.90, 16110.00, -4898.00, '2025-08-27 16:00:00'),
(8, 'AAPL', 100.0, 285.40, 18985.00, -8555.00, '2025-08-27 16:00:00'),
-- Portfolio 4 gets a massive loss position
(4, 'TSLA', 65.0, 280.45, 13101.40, -5128.85, '2025-08-27 16:00:00'),
-- Portfolio 2 gets another big loss  
(2, 'MSFT', 50.0, 520.75, 21157.50, -4681.00, '2025-08-27 16:00:00'),
-- Portfolio 6 gets a huge loss to trigger the alert
(6, 'TSLA', 75.0, 295.60, 15117.00, -7053.00, '2025-08-27 16:00:00'), -- Another big loss
-- Portfolio 8 gets multiple large losses
(8, 'GOOGL', 85.0, 185.45, 11411.25, -4341.00, '2025-08-27 16:00:00'),
(8, 'MSFT', 35.0, 465.80, 14810.25, -1488.75, '2025-08-27 16:00:00');

-- Recent Trades (Last 30 days)
INSERT INTO trades (portfolio_id, symbol, trade_type, quantity, price, total_amount, fees, trade_date, settlement_date, status) VALUES
(2, 'NVDA', 'BUY', 25.0, 890.25, 22256.25, 12.50, '2025-08-25 14:30:00', '2025-08-27', 'executed'),
(5, 'AAPL', 'SELL', 50.0, 192.80, 9640.00, 8.75, '2025-08-24 10:15:00', '2025-08-26', 'executed'),
(1, 'TLT', 'BUY', 50.0, 89.85, 4492.50, 5.25, '2025-08-23 11:45:00', '2025-08-25', 'executed'),
(4, 'V', 'BUY', 15.0, 268.45, 4026.75, 6.50, '2025-08-22 09:20:00', '2025-08-24', 'executed'),
(3, 'WMT', 'BUY', 20.0, 159.75, 3195.00, 4.25, '2025-08-21 15:10:00', '2025-08-23', 'executed'),
(8, 'TSLA', 'SELL', 30.0, 205.30, 6159.00, 7.80, '2025-08-20 13:25:00', '2025-08-22', 'executed'),
(7, 'SPY', 'BUY', 20.0, 545.80, 10916.00, 9.15, '2025-08-19 16:45:00', '2025-08-21', 'executed'),
(2, 'GOOGL', 'BUY', 50.0, 136.25, 6812.50, 6.25, '2025-08-18 12:30:00', '2025-08-20', 'executed'),
(5, 'MSFT', 'SELL', 20.0, 425.90, 8518.00, 8.50, '2025-08-17 14:20:00', '2025-08-19', 'executed'),
(6, 'JPM', 'BUY', 25.0, 176.40, 4410.00, 5.50, '2025-08-16 11:15:00', '2025-08-18', 'executed'),
-- FAILED TRADES FOR ALERT TESTING (recent failures)
(2, 'AAPL', 'BUY', 100.0, 195.50, 19550.00, 12.75, CURRENT_DATE, NULL, 'failed'),
(4, 'TSLA', 'SELL', 50.0, 205.80, 10290.00, 8.90, CURRENT_DATE, NULL, 'failed'),
(8, 'NVDA', 'BUY', 15.0, 895.25, 13428.75, 15.25, CURRENT_DATE, NULL, 'failed'),
(3, 'MSFT', 'BUY', 25.0, 430.75, 10768.75, 9.50, CURRENT_DATE, NULL, 'failed'),
(6, 'GOOGL', 'SELL', 30.0, 138.90, 4167.00, 6.75, CURRENT_DATE, NULL, 'failed');

-- Dividend Payments (Recent)
INSERT INTO dividend_payments (portfolio_id, symbol, shares_held, dividend_per_share, total_dividend, ex_dividend_date, payment_date, status) VALUES
(1, 'AAPL', 100.0, 0.24, 24.00, '2025-08-09', '2025-08-15', 'paid'),
(4, 'MSFT', 45.0, 0.75, 33.75, '2025-08-19', '2025-08-22', 'paid'),
(6, 'JPM', 45.0, 1.05, 47.25, '2025-07-30', '2025-08-05', 'paid'),
(3, 'JNJ', 80.0, 1.19, 95.20, '2025-08-25', '2025-08-28', 'ex_dividend'),
(3, 'WMT', 60.0, 0.57, 34.20, '2025-08-10', '2025-08-15', 'paid'),
(1, 'SPY', 45.0, 1.78, 80.10, '2025-09-15', '2025-09-20', 'announced'),
(7, 'VTI', 150.0, 0.89, 133.50, '2025-09-22', '2025-09-25', 'announced');

-- Portfolio Performance (Daily snapshots for last 30 days)
INSERT INTO portfolio_performance (portfolio_id, date, total_value, daily_return_pct, cumulative_return_pct, benchmark_return_pct, cash_balance) VALUES
-- Sample data for portfolios over recent days - MIXED SCENARIOS FOR ALERT TESTING
(1, CURRENT_DATE, 125000.00, -6.25, 12.50, 0.75, 5000.00), -- Large loss > 5%
(1, CURRENT_DATE - 1, 133500.00, -2.25, 15.59, -0.18, 5000.00),
(1, CURRENT_DATE - 2, 136750.00, 1.20, 18.87, 1.10, 5000.00),
(2, CURRENT_DATE, 245000.00, -7.45, 28.75, 0.75, 12000.00), -- Large loss > 5%
(2, CURRENT_DATE - 1, 264000.00, -3.68, 38.93, -0.18, 12000.00),
(2, CURRENT_DATE - 2, 274120.00, 2.10, 44.79, 1.10, 12000.00),
(3, CURRENT_DATE, 75000.00, -5.85, 8.25, 0.75, 8000.00), -- Large loss > 5%
(3, CURRENT_DATE - 1, 79650.00, -1.15, 14.87, -0.18, 8000.00),
(3, CURRENT_DATE - 2, 80650.00, 0.45, 16.04, 1.10, 8000.00),
(4, CURRENT_DATE, 180000.00, -8.20, 22.50, 0.75, 3500.00), -- Large loss > 5%  
(4, CURRENT_DATE - 1, 196000.00, -1.25, 33.59, -0.18, 3500.00),
(4, CURRENT_DATE - 2, 198500.00, 1.80, 35.87, 1.10, 3500.00),
(5, CURRENT_DATE, 320000.00, 1.45, 55.75, 0.75, 16000.00), -- Good performance
(5, CURRENT_DATE - 1, 315480.00, -0.68, 53.93, -0.18, 16000.00),
(5, CURRENT_DATE - 2, 317120.00, 2.10, 54.79, 1.10, 16000.00),
(6, CURRENT_DATE, 95000.00, -0.35, 8.25, 0.75, 2500.00), -- Minor loss < 5%
(6, CURRENT_DATE - 1, 95335.00, 0.15, 8.87, -0.18, 2500.00),
(6, CURRENT_DATE - 2, 95185.00, -0.45, 8.54, 1.10, 2500.00),
(7, CURRENT_DATE, 210000.00, 0.85, 28.75, 0.75, 8500.00), -- Good performance
(7, CURRENT_DATE - 1, 208215.00, -0.25, 27.93, -0.18, 8500.00),
(7, CURRENT_DATE - 2, 208735.00, 1.20, 28.24, 1.10, 8500.00),
(8, CURRENT_DATE, 85000.00, -6.75, 18.25, 0.75, 1700.00); -- Large loss > 5%

-- Risk Metrics (Weekly calculations) - UPDATED FOR ALERT TESTING
INSERT INTO risk_metrics (portfolio_id, calculation_date, volatility_30d, beta, sharpe_ratio, max_drawdown, var_95, sector_concentration, top_10_concentration) VALUES
(1, CURRENT_DATE, 12.45, 0.95, 1.25, -8.50, -5250.00, '{"Technology": 35, "Healthcare": 15, "Financials": 20, "Consumer": 15, "Fixed Income": 15}', 45.2),
(2, CURRENT_DATE, 28.80, 1.35, 1.85, -15.20, -18750.00, '{"Technology": 75, "Consumer": 20, "Cash": 5}', 68.5), -- High volatility > 25%
(3, CURRENT_DATE, 18.95, 0.75, 0.95, -5.80, -3200.00, '{"Healthcare": 25, "Consumer": 30, "Financials": 20, "Fixed Income": 25}', 38.7),
(4, CURRENT_DATE, 15.60, 1.05, 1.45, -9.80, -8950.00, '{"Technology": 40, "Financials": 25, "Fixed Income": 20, "Diversified": 15}', 52.3),
(5, CURRENT_DATE, 32.75, 1.65, 2.10, -18.50, -28500.00, '{"Technology": 95, "Cash": 5}', 89.2), -- High volatility > 25% AND high concentration > 80%
(6, CURRENT_DATE, 26.40, 0.85, 1.15, -12.30, -8500.00, '{"Dividend": 85, "Cash": 15}', 82.1), -- High concentration > 80%
(7, CURRENT_DATE, 14.20, 1.00, 1.35, -7.20, -6200.00, '{"Diversified": 60, "Technology": 25, "Fixed Income": 15}', 52.8),
(8, CURRENT_DATE, 35.60, 1.85, 1.95, -22.80, -15500.00, '{"Speculative": 90, "Cash": 10}', 87.5); -- High volatility > 25% AND high concentration > 80%

-- Create indexes for better performance
CREATE INDEX idx_trades_portfolio_date ON trades(portfolio_id, trade_date);
CREATE INDEX idx_positions_portfolio ON positions(portfolio_id);
CREATE INDEX idx_performance_portfolio_date ON portfolio_performance(portfolio_id, date);
CREATE INDEX idx_market_data_symbol ON market_data(symbol);
CREATE INDEX idx_dividend_payments_portfolio ON dividend_payments(portfolio_id);

-- Create test user for database connection
-- Note: PostgreSQL user creation syntax
-- This should be run separately with appropriate privileges:
-- CREATE USER test_user WITH PASSWORD 'test_pass';
-- GRANT CONNECT ON DATABASE test TO test_user;
-- GRANT USAGE ON SCHEMA public TO test_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO test_user;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO test_user;