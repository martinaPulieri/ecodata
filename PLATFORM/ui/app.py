"""Optional prototype status interface; scientific workflows are not implemented."""
import os

import httpx2 as httpx
import streamlit as st

st.set_page_config(page_title="Ecological Data Platform")
st.title("Ecological Data Integration Platform")
st.caption("Research prototype foundation. Scientific workflows are not implemented yet.")
api_url = os.environ.get("ECODATA_API_URL", "http://localhost:8000").rstrip("/")

if st.button("Check API and database", type="primary"):
    try:
        response = httpx.get(f"{api_url}/health/ready", timeout=15)
        if response.status_code == 200:
            st.success("API and database are ready.")
        elif response.status_code == 503:
            st.warning("API is running; the database is unavailable.")
        else:
            st.error(f"Health check returned HTTP {response.status_code}.")
    except httpx.RequestError:
        st.error("Cannot reach the API. Check the backend URL and startup logs.")
