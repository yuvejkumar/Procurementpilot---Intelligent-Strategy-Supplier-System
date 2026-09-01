import os
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score
from sklearn.model_selection import train_test_split

# 1. Load dataset
dataset_path = "lib/procurement_training_dataset.csv"
if not os.path.exists(dataset_path):
    dataset_path = "procurement_training_dataset.csv"  # Fallback if run from lib folder

df = pd.read_csv(dataset_path)

print("\nDATASET COLUMNS:")
print(df.columns.tolist())

# 2. Convert categorical columns to numerical columns
df_encoded = pd.get_dummies(
    df,
    columns=["supplier_category", "disruption_type"]
)

# 3. Input features
feature_cols = [
    "historical_unit_price",
    "current_unit_price",
    "historical_reliability_pct",
    "current_reliability_pct",
    "historical_quality_score",
    "current_quality_score",
    "historical_delivery_days",
    "current_delivery_days",
    "max_capacity",
    "min_order_quantity",
    "required_quantity",
    "on_time_delivery_pct",
    "defect_rate_pct",
    "price_volatility_pct",
    "capacity_utilization_pct",
    "disruption_severity_pct",
]

# Automatically add encoded categorical columns
feature_cols += [
    col for col in df_encoded.columns
    if col.startswith("supplier_category_")
    or col.startswith("disruption_type_")
]

# X = Features
X = df_encoded[feature_cols]

# Y = Target
y = df_encoded["predicted_overall_risk_score"]

# 4. Train / Test split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.2,
    random_state=42
)

# 5. Train Random Forest
print("\n⚙️ Training Random Forest Model...")
model = RandomForestRegressor(
    n_estimators=100,
    random_state=42,
    n_jobs=-1
)

model.fit(X_train, y_train)

# 6. Predict & Evaluate
predictions = model.predict(X_test)
score = r2_score(y_test, predictions)

print("\n✅ Model trained successfully!")
print(f"📊 R2 Accuracy Score: {score:.4f} ({score * 100:.2f}%)")

# ============================================================
# 💾 SAVE THE MODEL TO DISK
# ============================================================
model_filename = "procurement_risk_model.joblib"
features_filename = "model_features.joblib"

joblib.dump(model, model_filename)
joblib.dump(feature_cols, features_filename)

print("\n====================================================")
print(f"💾 MODEL SAVED TO  : {os.path.abspath(model_filename)}")
print(f"💾 FEATURES SAVED TO: {os.path.abspath(features_filename)}")
print("====================================================")