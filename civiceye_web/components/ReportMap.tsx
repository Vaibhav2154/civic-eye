'use client';

import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import type { LatLngExpression } from 'leaflet'; 
import 'leaflet/dist/leaflet.css';

interface MapProps {
  lat: number;
  lng: number;
}

export default function ReportMap({ lat, lng }: MapProps) {
  const position: LatLngExpression = [lat, lng]; 

  return (
    <MapContainer
      center={position}
      zoom={13}
      scrollWheelZoom={false}
      style={{ height: '100%', width: '100%' }}
    >
      <TileLayer
        attribution='&copy; OpenStreetMap contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={position}>
        <Popup>Reported Location</Popup>
      </Marker>
    </MapContainer>
  );
}
