// app/(dashboard)/layout.tsx
"use client";



export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    //<SidebarProvider>
  //<AppSidebar/>
  //<SidebarTrigger/>
  <main className="">
    
    {children}
  </main>
//</SidebarProvider>

  );
}
