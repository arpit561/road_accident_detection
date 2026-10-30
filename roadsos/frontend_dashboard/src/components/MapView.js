import React, { useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

const defaultCenter = [13.0681, 80.2148]; // Koyambedu, Chennai default

// Component to dynamically change map view center
const ChangeMapCenter = ({ center, zoom }) => {
  const map = useMap();
  useEffect(() => {
    if (center) {
      map.setView(center, zoom || map.getZoom());
    }
  }, [center, zoom, map]);
  return null;
};

// Custom keyframe styles for Leaflet pulsing marker in light mode
const pulseStyles = `
  @keyframes mapPulse {
    0% { transform: scale(0.5); opacity: 1; }
    100% { transform: scale(1.6); opacity: 0; }
  }
`;

// Helper to create custom divIcon for incident
const createCustomMarker = (status, severity, isSelected) => {
  const color = '#EF4444'; // Red for incident
  const size = isSelected ? 40 : 32;
  const innerSize = isSelected ? 28 : 22;
  const fontSize = isSelected ? '14px' : '11px';

  return L.divIcon({
    html: `
      <div style="position: relative; width: ${size}px; height: ${size}px; display: flex; align-items: center; justify-content: center;">
        ${status !== 'RESOLVED' ? `
          <div style="
            position: absolute; 
            width: ${size + 24}px; 
            height: ${size + 24}px; 
            border-radius: 50%; 
            background-color: rgba(239, 68, 68, 0.12);
            border: 1.5px solid rgba(239, 68, 68, 0.3); 
            animation: mapPulse 1.8s infinite ease-out;
            opacity: 0.8;
          "></div>
        ` : ''}
        <div style="
          width: ${innerSize}px; 
          height: ${innerSize}px; 
          border-radius: 50%; 
          background-color: ${color}; 
          border: 2.5px solid #FFFFFF; 
          box-shadow: 0 4px 10px rgba(239, 68, 68, 0.35); 
          z-index: 2;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: all 0.2s ease;
        ">
          <span style="color: #FFFFFF; font-weight: 900; font-family: system-ui, sans-serif; font-size: ${fontSize}; line-height: 1;">
            ${status === 'RESOLVED' ? '✓' : '!'}
          </span>
        </div>
      </div>
    `,
    className: 'custom-leaflet-icon',
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2]
  });
};

// Helper to create custom helper/volunteer markers (orange & green circles with numbers)
const createHelperMarker = (count, color) => {
  return L.divIcon({
    html: `
      <div style="
        width: 24px; 
        height: 24px; 
        border-radius: 50%; 
        background-color: ${color}; 
        border: 2px solid #FFFFFF; 
        display: flex; 
        align-items: center; 
        justify-content: center; 
        box-shadow: 0 2px 6px rgba(0,0,0,0.18);
        z-index: 2;
      ">
        <span style="color: #FFFFFF; font-weight: 700; font-size: 11px; font-family: system-ui, sans-serif;">
          ${count}
        </span>
      </div>
    `,
    className: 'custom-leaflet-icon-helper',
    iconSize: [24, 24],
    iconAnchor: [12, 12]
  });
};

// Generate simulated helper locations around active incidents to match the dashboard screenshot
const generateMockHelpers = (incidents) => {
  const helpers = [];
  incidents.forEach((inc) => {
    if (inc.status !== 'RESOLVED' && inc.latitude && inc.longitude) {
      // Helper 1 (orange, count 2) - North West
      helpers.push({
        id: `h-orange-${inc.id}`,
        lat: inc.latitude + 0.0035,
        lng: inc.longitude - 0.0075,
        count: 2,
        color: '#F59E0B' // Amber
      });
      // Helper 2 (green, count 3) - South East
      helpers.push({
        id: `h-green-${inc.id}`,
        lat: inc.latitude - 0.0065,
        lng: inc.longitude + 0.0055,
        count: 3,
        color: '#10B981' // Green
      });
    }
  });
  return helpers;
};

const MapView = ({ incidents = [], selectedIncident, onSelectIncident }) => {
  // Inject keyframe stylesheet for pulsing animations if not present
  useEffect(() => {
    if (!document.getElementById('leaflet-custom-styles')) {
      const style = document.createElement('style');
      style.id = 'leaflet-custom-styles';
      style.innerHTML = pulseStyles;
      document.head.appendChild(style);
    }
  }, []);

  const center = selectedIncident 
    ? [selectedIncident.latitude, selectedIncident.longitude]
    : incidents.length > 0
      ? [incidents[0].latitude, incidents[0].longitude]
      : defaultCenter;

  const zoom = selectedIncident ? 14 : incidents.length > 0 ? 12 : 10;
  const mockHelpers = generateMockHelpers(incidents);

  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <MapContainer 
        center={center} 
        zoom={zoom} 
        style={{ width: '100%', height: '100%', background: '#F8F9FA' }}
        zoomControl={false}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png?key=cb1_4r4r_1_dde52cb572907cb310bf6355"
        />
        
        {/* Active Incident Markers */}
        {incidents.map((inc) => {
          if (!inc.latitude || !inc.longitude) return null;
          const isSelected = selectedIncident?.id === inc.id;
          return (
            <Marker
              key={inc.id}
              position={[inc.latitude, inc.longitude]}
              icon={createCustomMarker(inc.status, inc.severity, isSelected)}
              eventHandlers={{
                click: () => onSelectIncident(inc)
              }}
            >
              <Popup className="custom-leaflet-popup">
                <div style={{ color: 'var(--text-primary)', fontFamily: 'Inter, sans-serif' }}>
                  <strong style={{ display: 'block', fontSize: '13px', marginBottom: '4px' }}>
                    {inc.city || 'Accident Reported'}
                  </strong>
                  <span style={{ display: 'block', fontSize: '11px', color: 'var(--text-secondary)', marginBottom: '8px' }}>
                    Severity: <span style={{ 
                      color: inc.severity === 'CRITICAL' ? '#8B5CF6' : inc.severity === 'HIGH' ? '#EF4444' : '#F59E0B',
                      fontWeight: 'bold'
                    }}>{inc.severity}</span>
                  </span>
                  <button 
                    onClick={() => onSelectIncident(inc)}
                    style={{
                      background: 'var(--color-red-light)',
                      color: 'var(--color-red)',
                      border: '1px solid var(--color-red-border)',
                      padding: '4px 8px',
                      borderRadius: '4px',
                      fontSize: '11px',
                      cursor: 'pointer',
                      width: '100%',
                      fontWeight: '600'
                    }}
                  >
                    View Details
                  </button>
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* Mock Volunteer Clusters around incidents */}
        {mockHelpers.map((helper) => (
          <Marker
            key={helper.id}
            position={[helper.lat, helper.lng]}
            icon={createHelperMarker(helper.count, helper.color)}
          />
        ))}
        
        <ChangeMapCenter center={center} zoom={zoom} />
      </MapContainer>
      
      {/* Floating HUD radar indicator */}
      <div style={{
        position: 'absolute',
        top: '16px',
        left: '16px',
        zIndex: 1000,
        background: 'rgba(255, 255, 255, 0.9)',
        backdropFilter: 'blur(8px)',
        border: '1px solid var(--border-color)',
        borderRadius: '8px',
        padding: '8px 12px',
        pointerEvents: 'none',
        boxShadow: '0 2px 8px rgba(0,0,0,0.06)'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
          <span style={{ 
            width: '6px', 
            height: '6px', 
            borderRadius: '50%', 
            backgroundColor: '#10B981', 
            display: 'inline-block',
            boxShadow: '0 0 4px #10B981',
            animation: 'mapPulse 1.5s infinite ease-out'
          }}></span>
          <span style={{ fontSize: '10px', fontWeight: 'bold', color: 'var(--text-primary)', letterSpacing: '0.5px', fontFamily: 'var(--font-head)' }}>
            LIVE GPS FEED ACTIVE
          </span>
        </div>
      </div>
    </div>
  );
};

export default MapView;
