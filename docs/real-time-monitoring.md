# Real-Time Monitoring with OCPP Rails

This guide explains how to monitor charge points, connectors, sessions, and meter values in real-time using the OCPP Rails models and ActionCable broadcasts.

## Overview

OCPP Rails provides a complete backend for OCPP protocol communication but **does not include any UI**. Your application is responsible for building the user interface, while OCPP Rails handles:

1. **WebSocket Communication** - Bidirectional OCPP protocol messages with charge points
2. **Data Models** - Store charge point status, sessions, and meter values
3. **Real-time Broadcasts** - ActionCable broadcasts for live UI updates
4. **Remote Control** - Jobs to send commands to charge points

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Application                          │
│  - Controllers & Views                                       │
│  - Authentication & Authorization                            │
│  - Business Logic                                            │
│  - ActionCable Channels (for UI)                             │
└──────────────────────┬──────────────────────────────────────┘
                       │ Uses Models & Subscribes to Broadcasts
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    OCPP Rails Gem                            │
│  - ChargePointChannel (OCPP WebSocket)                       │
│  - Message Handlers                                          │
│  - Models (ChargePoint, ChargingSession, MeterValue)         │
│  - ActionCable Broadcasts (status, sessions, meter_values)   │
└──────────────────────┬──────────────────────────────────────┘
                       │ OCPP Protocol
                       ▼
┌─────────────────────────────────────────────────────────────┐
│               Charge Points (Hardware)                       │
└─────────────────────────────────────────────────────────────┘
```

---

## Monitoring Charge Point Status

### Using Models (Polling)

Query charge points directly from the database:

```ruby
# Get all connected charge points
connected_cps = Ocpp::Rails::ChargePoint.connected

# Get all available charge points
available_cps = Ocpp::Rails::ChargePoint.available

# Get all charge points currently charging
charging_cps = Ocpp::Rails::ChargePoint.charging

# Check specific charge point
cp = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
cp.connected?         # => true/false
cp.available?         # => true if status is "Available" and connected
cp.status             # => "Available", "Charging", "Preparing", etc.
cp.last_heartbeat_at  # => 2024-01-15 10:30:00 UTC
cp.vendor             # => "ChargePoint Vendor"
cp.model              # => "Model X"
```

#### Example: Dashboard Controller

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @connected_count = Ocpp::Rails::ChargePoint.connected.count
    @available_count = Ocpp::Rails::ChargePoint.available.count
    @charging_count = Ocpp::Rails::ChargePoint.charging.count
    @charge_points = Ocpp::Rails::ChargePoint.order(:identifier)
  end
end
```

### Real-Time Updates via ActionCable

OCPP Rails broadcasts status changes when charge points send `StatusNotification` messages. Subscribe to these broadcasts in your UI.

#### Step 1: Create a Channel in Your App

```ruby
# app/channels/charge_point_status_channel.rb
class ChargePointStatusChannel < ApplicationCable::Channel
  def subscribed
    charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
    stream_from "charge_point_#{charge_point.id}_status"
  end

  def unsubscribed
    # Cleanup
  end
end
```

#### Step 2: Subscribe in JavaScript

```javascript
// app/javascript/channels/charge_point_status_channel.js
import consumer from "./consumer"

export function subscribeToChargePointStatus(chargePointId, callbacks) {
  return consumer.subscriptions.create(
    { 
      channel: "ChargePointStatusChannel",
      charge_point_id: chargePointId 
    },
    {
      connected() {
        console.log(`Subscribed to charge point ${chargePointId} status updates`);
      },

      disconnected() {
        console.log(`Unsubscribed from charge point ${chargePointId}`);
      },

      received(data) {
        // data = {
        //   connector_id: 1,
        //   status: "Charging",
        //   error_code: "NoError",
        //   info: "",
        //   timestamp: "2024-01-15T10:30:00Z"
        // }
        if (callbacks.onStatusChange) {
          callbacks.onStatusChange(data);
        }
      }
    }
  );
}
```

#### Step 3: Use in Your UI

```javascript
// Example: Update charge point card in real-time
import { subscribeToChargePointStatus } from "./channels/charge_point_status_channel"

document.addEventListener('DOMContentLoaded', () => {
  const chargePointId = document.getElementById('charge-point-card').dataset.id;
  
  subscribeToChargePointStatus(chargePointId, {
    onStatusChange: (data) => {
      // Update connector status badge
      const badge = document.querySelector(`[data-connector="${data.connector_id}"]`);
      badge.textContent = data.status;
      badge.className = `badge badge-${getStatusColor(data.status)}`;
      
      // Show error if present
      if (data.error_code !== 'NoError') {
        showError(`Connector ${data.connector_id}: ${data.error_code}`);
      }
    }
  });
});

function getStatusColor(status) {
  const colors = {
    'Available': 'success',
    'Charging': 'primary',
    'Preparing': 'warning',
    'Finishing': 'info',
    'Unavailable': 'secondary',
    'Faulted': 'danger'
  };
  return colors[status] || 'secondary';
}
```

---

## Monitoring Connector Status

### Using Models

Connector status is stored in the charge point's metadata JSON field:

```ruby
cp = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")

# Get connector 1 status
connector_1_status = cp.metadata["connector_1_status"]
# => "Available", "Charging", "Preparing", "Finishing", etc.

# Get connector error code
connector_1_error = cp.metadata["connector_1_error_code"]
# => "NoError", "ConnectorLockFailure", etc.

# Get last update time
connector_1_updated = cp.metadata["connector_1_updated_at"]
# => "2024-01-15T10:30:00Z"

# List all connectors
connectors = cp.metadata.select { |k, v| k.start_with?("connector_") && k.end_with?("_status") }
# => {"connector_1_status"=>"Available", "connector_2_status"=>"Charging"}
```

### Best Practice: Connector Model (Optional)

For better organization and queries, consider creating a Connector model in your app:

```ruby
# db/migrate/XXXXXX_create_connectors.rb
class CreateConnectors < ActiveRecord::Migration[7.0]
  def change
    create_table :connectors do |t|
      t.references :charge_point, null: false, foreign_key: { to_table: :ocpp_charge_points }
      t.integer :connector_id, null: false
      t.string :status, default: 'Unknown'
      t.string :error_code, default: 'NoError'
      t.string :info
      t.datetime :last_update_at
      t.timestamps
    end

    add_index :connectors, [:charge_point_id, :connector_id], unique: true
  end
end
```

```ruby
# app/models/connector.rb
class Connector < ApplicationRecord
  belongs_to :charge_point, class_name: "Ocpp::Rails::ChargePoint"

  STATUSES = %w[Available Preparing Charging SuspendedEVSE SuspendedEV 
                Finishing Reserved Unavailable Faulted].freeze

  validates :connector_id, presence: true, uniqueness: { scope: :charge_point_id }
  validates :status, inclusion: { in: STATUSES }

  scope :available, -> { where(status: 'Available') }
  scope :charging, -> { where(status: 'Charging') }
  scope :faulted, -> { where.not(error_code: 'NoError') }

  def available?
    status == 'Available' && error_code == 'NoError'
  end

  def faulted?
    error_code != 'NoError'
  end
end
```

#### Override StatusNotificationHandler (Advanced)

To populate your Connector model, override the handler:

```ruby
# app/services/ocpp/rails/actions/status_notification_handler.rb
module Ocpp
  module Rails
    module Actions
      class StatusNotificationHandler
        def initialize(charge_point, message_id, payload)
          @charge_point = charge_point
          @message_id = message_id
          @payload = payload
        end

        def call
          connector_id = @payload['connectorId']
          status = @payload['status']

          # Update or create connector record
          connector = Connector.find_or_create_by(
            charge_point: @charge_point,
            connector_id: connector_id
          )

          connector.update(
            status: status,
            error_code: @payload['errorCode'] || 'NoError',
            info: @payload['info'],
            last_update_at: Time.current
          )

          # Also update charge point status if connector 0 (whole station)
          if connector_id == 0
            @charge_point.update(status: status)
          end

          # Broadcast status change
          broadcast_status_change

          {}
        end

        private

        def broadcast_status_change
          ActionCable.server.broadcast(
            "charge_point_#{@charge_point.id}_status",
            {
              connector_id: @payload['connectorId'],
              status: @payload['status'],
              error_code: @payload['errorCode'],
              info: @payload['info'],
              timestamp: Time.current.iso8601
            }
          )
        end
      end
    end
  end
end
```

---

## Monitoring Active Sessions

### Using Models

```ruby
# Get all active sessions across all charge points
active_sessions = Ocpp::Rails::ChargingSession.active

# Get active sessions for a specific charge point
cp = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
cp_sessions = cp.charging_sessions.active

# Get current session (most recent active)
current_session = cp.current_session

# Session details
if current_session
  current_session.connector_id        # => 1
  current_session.id_tag              # => "RFID12345"
  current_session.started_at          # => 2024-01-15 10:00:00 UTC
  current_session.duration_seconds    # => 1800
  current_session.energy_consumed     # => 5.5 (kWh)
  current_session.status              # => "Charging"
  current_session.start_meter_value   # => 12345.0
end

# Get completed sessions
completed_sessions = cp.charging_sessions.completed.order(stopped_at: :desc).limit(10)
```

#### Example: Sessions Index Controller

```ruby
# app/controllers/charging_sessions_controller.rb
class ChargingSessionsController < ApplicationController
  def index
    @active_sessions = Ocpp::Rails::ChargingSession.active.includes(:charge_point)
    @recent_sessions = Ocpp::Rails::ChargingSession.completed
                                                   .includes(:charge_point)
                                                   .order(stopped_at: :desc)
                                                   .limit(50)
  end

  def show
    @session = Ocpp::Rails::ChargingSession.find(params[:id])
    @meter_values = @session.meter_values.order(:timestamp)
  end
end
```

### Real-Time Session Updates

OCPP Rails broadcasts session events (started/stopped). Subscribe to receive live updates.

#### Step 1: Create a Channel in Your App

```ruby
# app/channels/charging_session_channel.rb
class ChargingSessionChannel < ApplicationCable::Channel
  def subscribed
    charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
    stream_from "charge_point_#{charge_point.id}_sessions"
  end
end
```

#### Step 2: Subscribe in JavaScript

```javascript
// app/javascript/channels/charging_session_channel.js
import consumer from "./consumer"

export function subscribeToSessions(chargePointId, callbacks) {
  return consumer.subscriptions.create(
    { 
      channel: "ChargingSessionChannel",
      charge_point_id: chargePointId 
    },
    {
      received(data) {
        // data = {
        //   event: "started" | "stopped",
        //   session: { id, connector_id, id_tag, started_at, ... }
        // }
        if (data.event === "started" && callbacks.onSessionStarted) {
          callbacks.onSessionStarted(data.session);
        } else if (data.event === "stopped" && callbacks.onSessionStopped) {
          callbacks.onSessionStopped(data.session);
        }
      }
    }
  );
}
```

#### Step 3: Use in Your UI

```javascript
import { subscribeToSessions } from "./channels/charging_session_channel"

subscribeToSessions(chargePointId, {
  onSessionStarted: (session) => {
    console.log(`Session started on connector ${session.connector_id}`);
    // Add new session to UI
    addSessionToTable(session);
    updateConnectorStatus(session.connector_id, 'Charging');
  },
  
  onSessionStopped: (session) => {
    console.log(`Session stopped: ${session.energy_consumed} kWh`);
    // Update session in UI
    updateSessionInTable(session);
    showNotification(`Charging complete: ${session.energy_consumed} kWh`);
  }
});
```

---

## Monitoring Meter Values

### Using Models

```ruby
# Get latest meter values for a charge point
cp = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
latest_values = cp.meter_values.recent.limit(10)

# Get latest energy reading
latest_energy = cp.meter_values.energy.recent.first
if latest_energy
  latest_energy.value  # => 12345.67
  latest_energy.unit   # => "Wh"
  latest_energy.timestamp
end

# Get latest power reading
latest_power = cp.meter_values.power.recent.first
if latest_power
  latest_power.value   # => 7200.0
  latest_power.unit    # => "W"
end

# Get meter values for a specific session
session = cp.current_session
if session
  session_values = session.meter_values.order(timestamp: :asc)
  
  # Calculate energy over time
  energy_readings = session_values.where(measurand: 'Energy.Active.Import.Register')
  power_readings = session_values.where(measurand: 'Power.Active.Import')
end

# Get specific measurand types
voltage_readings = cp.meter_values.voltage.recent.limit(10)
current_readings = cp.meter_values.current.recent.limit(10)

# All available measurand scopes:
# - energy: Energy.Active.Import.Register
# - power: Power.Active.Import
# - current: Current.Import
# - voltage: Voltage
```

#### Example: Meter Values API Endpoint

```ruby
# app/controllers/api/meter_values_controller.rb
module Api
  class MeterValuesController < ApplicationController
    def index
      charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
      
      meter_values = charge_point.meter_values
                                 .where('timestamp > ?', 1.hour.ago)
                                 .order(timestamp: :asc)
      
      # Group by measurand for charting
      grouped = meter_values.group_by(&:measurand).transform_values do |values|
        values.map { |v| { timestamp: v.timestamp, value: v.value.to_f, unit: v.unit } }
      end
      
      render json: grouped
    end
  end
end
```

### Real-Time Meter Values via ActionCable

OCPP Rails automatically broadcasts meter values when received from charge points. This is perfect for live dashboards showing current power, energy, voltage, etc.

#### Step 1: Create a Channel in Your App

```ruby
# app/channels/meter_values_channel.rb
class MeterValuesChannel < ApplicationCable::Channel
  def subscribed
    charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
    stream_from "charge_point_#{charge_point.id}_meter_values"
  end
end
```

#### Step 2: Subscribe in JavaScript

```javascript
// app/javascript/channels/meter_values_channel.js
import consumer from "./consumer"

export function subscribeToMeterValues(chargePointId, callbacks) {
  return consumer.subscriptions.create(
    { 
      channel: "MeterValuesChannel",
      charge_point_id: chargePointId 
    },
    {
      received(data) {
        // data = {
        //   connector_id: 1,
        //   measurand: "Energy.Active.Import.Register",
        //   value: 12345.67,
        //   unit: "Wh",
        //   phase: null,
        //   context: "Sample.Periodic",
        //   timestamp: "2024-01-15T10:30:00Z",
        //   session_id: 123
        // }
        
        if (callbacks.onMeterValue) {
          callbacks.onMeterValue(data);
        }
        
        // Call specific callbacks based on measurand
        const measurandCallbacks = {
          'Energy.Active.Import.Register': callbacks.onEnergy,
          'Power.Active.Import': callbacks.onPower,
          'Voltage': callbacks.onVoltage,
          'Current.Import': callbacks.onCurrent,
          'Temperature': callbacks.onTemperature,
          'SoC': callbacks.onSoC  // State of Charge
        };
        
        const callback = measurandCallbacks[data.measurand];
        if (callback) {
          callback(data);
        }
      }
    }
  );
}
```

#### Step 3: Use in Your Live Dashboard

```javascript
// Example: Real-time charging dashboard
import { subscribeToMeterValues } from "./channels/meter_values_channel"
import Chart from 'chart.js/auto'

class ChargingDashboard {
  constructor(chargePointId) {
    this.chargePointId = chargePointId;
    this.powerChart = this.createPowerChart();
    this.energyChart = this.createEnergyChart();
    this.subscribe();
  }

  subscribe() {
    subscribeToMeterValues(this.chargePointId, {
      onPower: (data) => {
        // Update power gauge/chart
        document.getElementById('current-power').textContent = 
          `${(data.value / 1000).toFixed(2)} kW`;
        this.addDataToChart(this.powerChart, data.timestamp, data.value / 1000);
      },

      onEnergy: (data) => {
        // Update energy counter
        document.getElementById('total-energy').textContent = 
          `${(data.value / 1000).toFixed(2)} kWh`;
        this.addDataToChart(this.energyChart, data.timestamp, data.value / 1000);
      },

      onVoltage: (data) => {
        // Update voltage display
        const element = document.getElementById(`voltage-phase-${data.phase || 'L1'}`);
        if (element) {
          element.textContent = `${data.value.toFixed(1)} V`;
        }
      },

      onCurrent: (data) => {
        // Update current display
        const element = document.getElementById(`current-phase-${data.phase || 'L1'}`);
        if (element) {
          element.textContent = `${data.value.toFixed(1)} A`;
        }
      },

      onSoC: (data) => {
        // Update battery state of charge (if EV provides it)
        document.getElementById('battery-soc').textContent = `${data.value}%`;
        updateBatteryIcon(data.value);
      }
    });
  }

  createPowerChart() {
    const ctx = document.getElementById('power-chart').getContext('2d');
    return new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: 'Power (kW)',
          data: [],
          borderColor: 'rgb(75, 192, 192)',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        scales: {
          x: { type: 'time' },
          y: { beginAtZero: true }
        }
      }
    });
  }

  createEnergyChart() {
    const ctx = document.getElementById('energy-chart').getContext('2d');
    return new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: 'Energy (kWh)',
          data: [],
          borderColor: 'rgb(255, 99, 132)',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        scales: {
          x: { type: 'time' },
          y: { beginAtZero: true }
        }
      }
    });
  }

  addDataToChart(chart, timestamp, value) {
    chart.data.labels.push(new Date(timestamp));
    chart.data.datasets[0].data.push(value);
    
    // Keep only last 50 data points
    if (chart.data.labels.length > 50) {
      chart.data.labels.shift();
      chart.data.datasets[0].data.shift();
    }
    
    chart.update('none'); // Update without animation for performance
  }
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
  const chargePointId = document.getElementById('dashboard').dataset.chargePointId;
  new ChargingDashboard(chargePointId);
});
```

---

## Remote Control

Send commands to charge points using the provided jobs.

### Remote Start Transaction

```ruby
# From controller or service
charge_point = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")

Ocpp::Rails::RemoteStartTransactionJob.perform_later(
  charge_point.id,
  1,              # connector_id
  "RFID12345"     # id_tag
)

# Or perform immediately
Ocpp::Rails::RemoteStartTransactionJob.perform_now(
  charge_point.id,
  1,
  "RFID12345"
)
```

### Remote Stop Transaction

```ruby
charge_point = Ocpp::Rails::ChargePoint.find_by(identifier: "CP001")
session = charge_point.current_session

if session
  Ocpp::Rails::RemoteStopTransactionJob.perform_later(
    charge_point.id,
    session.id
  )
end
```

### Example: Remote Control API

```ruby
# app/controllers/api/remote_control_controller.rb
module Api
  class RemoteControlController < ApplicationController
    before_action :authenticate_user!
    before_action :set_charge_point

    def start
      unless @charge_point.available?
        return render json: { error: 'Charge point not available' }, status: :unprocessable_entity
      end

      Ocpp::Rails::RemoteStartTransactionJob.perform_later(
        @charge_point.id,
        params[:connector_id],
        params[:id_tag]
      )

      render json: { message: 'Remote start command sent' }, status: :accepted
    end

    def stop
      session = @charge_point.current_session

      unless session
        return render json: { error: 'No active session' }, status: :unprocessable_entity
      end

      Ocpp::Rails::RemoteStopTransactionJob.perform_later(
        @charge_point.id,
        session.id
      )

      render json: { message: 'Remote stop command sent' }, status: :accepted
    end

    private

    def set_charge_point
      @charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
    end
  end
end
```

---

## Complete Dashboard Example

Here's a complete example combining all monitoring features:

### Controller

```ruby
# app/controllers/monitoring_controller.rb
class MonitoringController < ApplicationController
  def dashboard
    @charge_points = Ocpp::Rails::ChargePoint.includes(:charging_sessions)
                                             .order(:identifier)
    @active_sessions = Ocpp::Rails::ChargingSession.active.includes(:charge_point)
    @stats = calculate_stats
  end

  def charge_point
    @charge_point = Ocpp::Rails::ChargePoint.find(params[:id])
    @current_session = @charge_point.current_session
    @recent_sessions = @charge_point.charging_sessions.completed
                                                       .order(stopped_at: :desc)
                                                       .limit(10)
    @recent_meter_values = @charge_point.meter_values.recent.limit(20)
  end

  private

  def calculate_stats
    {
      total_charge_points: Ocpp::Rails::ChargePoint.count,
      connected: Ocpp::Rails::ChargePoint.connected.count,
      available: Ocpp::Rails::ChargePoint.available.count,
      charging: Ocpp::Rails::ChargePoint.charging.count,
      active_sessions: Ocpp::Rails::ChargingSession.active.count,
      total_energy_today: calculate_energy_today
    }
  end

  def calculate_energy_today
    Ocpp::Rails::ChargingSession
      .where('started_at >= ?', Time.current.beginning_of_day)
      .sum(:energy_consumed)
  end
end
```

### View (ERB)

```erb
<%# app/views/monitoring/dashboard.html.erb %>
<div id="dashboard" data-auto-refresh="true">
  <h1>Charging Station Monitoring</h1>

  <%# Stats Overview %>
  <div class="stats-grid">
    <div class="stat-card">
      <h3><%= @stats[:total_charge_points] %></h3>
      <p>Total Charge Points</p>
    </div>
    <div class="stat-card connected">
      <h3><%= @stats[:connected] %></h3>
      <p>Connected</p>
    </div>
    <div class="stat-card available">
      <h3><%= @stats[:available] %></h3>
      <p>Available</p>
    </div>
    <div class="stat-card charging">
      <h3><%= @stats[:charging] %></h3>
      <p>Charging</p>
    </div>
  </div>

  <%# Charge Points List %>
  <div class="charge-points-grid">
    <% @charge_points.each do |cp| %>
      <div class="charge-point-card" 
           data-id="<%= cp.id %>" 
           data-identifier="<%= cp.identifier %>">
        
        <div class="card-header">
          <h3><%= cp.identifier %></h3>
          <span class="status-badge status-<%= cp.status.downcase %>">
            <%= cp.status %>
          </span>
        </div>

        <div class="card-body">
          <p><strong>Vendor:</strong> <%= cp.vendor %></p>
          <p><strong>Model:</strong> <%= cp.model %></p>
          <p>
            <strong>Connected:</strong> 
            <span class="connection-status">
              <%= cp.connected? ? '✓ Online' : '✗ Offline' %>
            </span>
          </p>
          <p><strong>Last Heartbeat:</strong> <%= time_ago_in_words(cp.last_heartbeat_at) %> ago</p>

          <% if cp.current_session %>
            <div class="current-session">
              <h4>Current Session</h4>
              <p>Duration: <span class="session-duration"><%= distance_of_time_in_words(cp.current_session.duration_seconds) %></span></p>
              <p>Energy: <span class="session-energy"><%= cp.current_session.energy_consumed %> kWh</span></p>
            </div>
          <% end %>
        </div>

        <div class="card-actions">
          <%= link_to 'Details', monitoring_charge_point_path(cp), class: 'btn btn-primary' %>
          
          <% if cp.available? %>
            <%= button_to 'Start Charging', start_remote_control_path(cp), 
                method: :post, class: 'btn btn-success' %>
          <% elsif cp.current_session %>
            <%= button_to 'Stop Charging', stop_remote_control_path(cp), 
                method: :post, class: 'btn btn-danger' %>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>

<%# Include ActionCable subscriptions %>
<%= javascript_include_tag 'monitoring', defer: true %>
```

### JavaScript (Stimulus or Vanilla)

```javascript
// app/javascript/monitoring.js
import { subscribeToChargePointStatus } from "./channels/charge_point_status_channel"
import { subscribeToSessions } from "./channels/charging_session_channel"
import { subscribeToMeterValues } from "./channels/meter_values_channel"

document.addEventListener('DOMContentLoaded', () => {
  // Subscribe to all charge points on the page
  document.querySelectorAll('.charge-point-card').forEach(card => {
    const chargePointId = card.dataset.id;
    
    // Status updates
    subscribeToChargePointStatus(chargePointId, {
      onStatusChange: (data) => {
        updateChargePointStatus(card, data);
      }
    });
    
    // Session updates
    subscribeToSessions(chargePointId, {
      onSessionStarted: (session) => {
        showNotification(`Charging started on ${card.dataset.identifier}`);
        updateSessionInfo(card, session);
      },
      onSessionStopped: (session) => {
        showNotification(`Charging complete: ${session.energy_consumed} kWh`);
        clearSessionInfo(card);
      }
    });
    
    // Meter values (for current session)
    subscribeToMeterValues(chargePointId, {
      onEnergy: (data) => {
        updateEnergyDisplay(card, data.value);
      },
      onPower: (data) => {
        updatePowerDisplay(card, data.value);
      }
    });
  });
  
  // Auto-refresh stats every 30 seconds
  setInterval(refreshStats, 30000);
});

function updateChargePointStatus(card, data) {
  const badge = card.querySelector('.status-badge');
  badge.textContent = data.status;
  badge.className = `status-badge status-${data.status.toLowerCase()}`;
}

function updateSessionInfo(card, session) {
  const sessionDiv = card.querySelector('.current-session') || 
                     createSessionDiv(card);
  sessionDiv.querySelector('.session-duration').textContent = 
    formatDuration(session.started_at);
  sessionDiv.querySelector('.session-energy').textContent = 
    `${session.energy_consumed || 0} kWh`;
}

function clearSessionInfo(card) {
  const sessionDiv = card.querySelector('.current-session');
  if (sessionDiv) {
    sessionDiv.remove();
  }
}

function updateEnergyDisplay(card, value) {
  const element = card.querySelector('.session-energy');
  if (element) {
    element.textContent = `${(value / 1000).toFixed(2)} kWh`;
  }
}

function updatePowerDisplay(card, value) {
  const element = card.querySelector('.current-power');
  if (element) {
    element.textContent = `${(value / 1000).toFixed(2)} kW`;
  }
}

function refreshStats() {
  fetch('/monitoring/stats')
    .then(response => response.json())
    .then(data => {
      document.querySelector('.stats-grid').innerHTML = renderStats(data);
    });
}

function showNotification(message) {
  // Implement your notification system
  console.log(message);
}
```

---

## Available Measurands

OCPP Rails supports all OCPP 1.6 measurands. Here are the most common ones:

| Measurand | Description | Typical Unit |
|-----------|-------------|--------------|
| `Energy.Active.Import.Register` | Total energy consumed | Wh |
| `Power.Active.Import` | Current power | W |
| `Current.Import` | Electric current | A |
| `Voltage` | Electric potential | V |
| `Current.Offered` | Maximum available current | A |
| `Power.Offered` | Maximum available power | W |
| `Temperature` | Temperature (battery, ambient) | Celsius |
| `SoC` | State of Charge (battery %) | Percent |
| `Frequency` | AC frequency | Hertz |
| `Power.Factor` | Power factor | - |

### Accessing Specific Measurands

```ruby
# Energy readings
energy_values = charge_point.meter_values
                           .where(measurand: 'Energy.Active.Import.Register')
                           .recent

# Power readings
power_values = charge_point.meter_values
                          .where(measurand: 'Power.Active.Import')
                          .recent

# Voltage readings (can be per-phase)
voltage_l1 = charge_point.meter_values
                        .where(measurand: 'Voltage', phase: 'L1')
                        .recent.first

# State of Charge (if EV provides it)
soc_values = charge_point.meter_values
                        .where(measurand: 'SoC')
                        .recent
```

---

## Performance Considerations

### Database Indexing

The OCPP Rails migrations include proper indexes, but consider additional indexes for your queries:

```ruby
# db/migrate/XXXXXX_add_custom_indexes.rb
class AddCustomIndexes < ActiveRecord::Migration[7.0]
  def change
    # Index for recent meter values by measurand
    add_index :ocpp_meter_values, [:charge_point_id, :measurand, :timestamp]
    
    # Index for active sessions lookup
    add_index :ocpp_charging_sessions, [:charge_point_id, :stopped_at]
  end
end
```

### Caching

Cache expensive queries:

```ruby
# Cache charge point status
def charge_point_status(cp)
  Rails.cache.fetch("charge_point_#{cp.id}_status", expires_in: 10.seconds) do
    {
      status: cp.status,
      connected: cp.connected?,
      current_session: cp.current_session&.as_json
    }
  end
end

# Invalidate cache on updates
ActionCable.server.broadcast("charge_point_#{cp.id}_status", data)
Rails.cache.delete("charge_point_#{cp.id}_status")
```

### ActionCable Performance

For high-traffic deployments:

1. **Use Redis** instead of async adapter
2. **Limit broadcast frequency** - aggregate meter values before broadcasting
3. **Use selective subscriptions** - only subscribe to what you need
4. **Implement pagination** - don't load all meter values at once

```ruby
# Example: Throttled meter value broadcasting
class MeterValuesHandler
  def broadcast_meter_value(meter_value)
    # Only broadcast every 5 seconds
    last_broadcast_key = "last_broadcast_#{@charge_point.id}"
    last_broadcast = Rails.cache.read(last_broadcast_key)
    
    if last_broadcast.nil? || last_broadcast < 5.seconds.ago
      ActionCable.server.broadcast(...)
      Rails.cache.write(last_broadcast_key, Time.current)
    end
  end
end
```

---

## Security Considerations

### Authenticating Charge Points

Override the channel to authenticate charge points:

```ruby
# app/channels/ocpp/rails/charge_point_channel.rb
module Ocpp
  module Rails
    class ChargePointChannel < ActionCable::Channel::Base
      def subscribed
        charge_point_id = params[:charge_point_id]
        auth_token = params[:auth_token]
        
        @charge_point = ChargePoint.find_by(identifier: charge_point_id)
        
        unless @charge_point && valid_auth_token?(@charge_point, auth_token)
          reject
          return
        end
        
        # ... rest of subscription logic
      end
      
      private
      
      def valid_auth_token?(charge_point, token)
        # Implement your authentication logic
        charge_point.auth_token == token
      end
    end
  end
end
```

### Authenticating Users (UI)

Use your app's authentication for UI channels:

```ruby
# app/channels/meter_values_channel.rb
class MeterValuesChannel < ApplicationCable::Channel
  def subscribed
    # Ensure user is authenticated
    reject unless current_user
    
    # Ensure user has access to this charge point
    charge_point = Ocpp::Rails::ChargePoint.find(params[:charge_point_id])
    reject unless can_access_charge_point?(charge_point)
    
    stream_from "charge_point_#{charge_point.id}_meter_values"
  end
  
  private
  
  def can_access_charge_point?(charge_point)
    # Implement your authorization logic
    current_user.can?(:read, charge_point)
  end
end
```

---

## Troubleshooting

See the [Troubleshooting Guide](troubleshooting.md) for real-time monitoring issues.

## Next Steps

- Read [ActionCable with SQLite Configuration](actioncable-sqlite.md)
- Review [API Reference](api-reference.md) for complete model documentation
- See [Message Reference](message-reference.md) for OCPP message formats
- Check [Getting Started](getting-started.md) for installation guide

---

**Need Help?**

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/your-repo/ocpp-rails/issues)
- 💬 [Discussions](https://github.com/your-repo/ocpp-rails/discussions)