let latencyChart;

async function loadTelemetry() {

    const response =
        await fetch("/telemetry");

    const data =
        await response.json();

    updateCards(data);

    updateTable(data);

    updateChart(data);
}

function updateCards(data) {

    document.getElementById("totalRequests")
        .innerText = data.length;

    const successCount =
        data.filter(x => x.success === 1).length;

    const successRate =
        ((successCount / data.length) * 100 || 0);

    document.getElementById("successRate")
        .innerText =
        successRate.toFixed(1) + "%";

    const avgLatency =
        data.reduce(
            (sum, item) =>
                sum + item.total_latency_in_sec,
            0
        ) / data.length || 0;

    document.getElementById("avgLatency")
        .innerText =
        avgLatency.toFixed(2) + " sec";

    const avgSqlTime =
        data.reduce(
            (sum, item) =>
                sum + item.sql_generation_total_time_ms,
            0
        ) / data.length || 0;

    document.getElementById("avgSqlTime")
        .innerText =
        avgSqlTime.toFixed(0) + " ms";
}

function updateTable(data) {

    const tbody =
        document.querySelector(
            "#requestTable tbody"
        );

    tbody.innerHTML = "";

    data.reverse().forEach(row => {

        const status =
            row.success === 1
                ? '<span class="success">Success</span>'
                : '<span class="failed">Failed</span>';

        tbody.innerHTML += `
        <tr>

            <td>${row.id}</td>

            <td>${row.question}</td>

            <td>${row.total_latency_in_sec.toFixed(2)}</td>

            <td>${row.schema_retrieval_total_time_ms.toFixed(0)}</td>

            <td>${row.sql_generation_total_time_ms.toFixed(0)}</td>

            <td>${row.performing_sql_query_total_time_ms.toFixed(0)}</td>

            <td>${row.repair_attempts}</td>

            <td>${status}</td>

        </tr>
        `;
    });
}

function updateChart(data) {

    const labels =
        data.map(x => x.id);

    const latencies =
        data.map(
            x => x.total_latency_in_sec
        );

    if(latencyChart){
        latencyChart.destroy();
    }

    const ctx =
        document
            .getElementById("latencyChart")
            .getContext("2d");

    latencyChart =
        new Chart(ctx, {

            type: "line",

            data: {

                labels: labels,

                datasets: [{
                    label: "Latency (sec)",
                    data: latencies,
                    borderWidth: 2,
                    tension: 0.3
                }]
            },

            options: {
                responsive:true
            }
        });
}

loadTelemetry();

setInterval(loadTelemetry, 5000);