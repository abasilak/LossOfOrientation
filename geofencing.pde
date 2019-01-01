import tomc.gpx.*;

import java.util.List;
import java.util.Date;
import java.text.SimpleDateFormat;

import de.fhpotsdam.unfolding.mapdisplay.*;
import de.fhpotsdam.unfolding.utils.*;
import de.fhpotsdam.unfolding.marker.*;
import de.fhpotsdam.unfolding.tiles.*;
import de.fhpotsdam.unfolding.interactions.*;
import de.fhpotsdam.unfolding.ui.*;
import de.fhpotsdam.unfolding.*;
import de.fhpotsdam.unfolding.core.*;
import de.fhpotsdam.unfolding.data.*;
import de.fhpotsdam.unfolding.geo.*;
import de.fhpotsdam.unfolding.texture.*;
import de.fhpotsdam.unfolding.events.*;
import de.fhpotsdam.utils.*;
import de.fhpotsdam.unfolding.providers.*;

PImage map_pin_red;
PImage map_pin_green;
PImage map_pin_old;
PImage map_bar_heatmap;

Route                     myRoute;
Fence                     myFence;
Fence                     myGoals;
UnfoldingMap              myMap;
List<AbstractMapProvider> myProviders;

int    curr_provider      = 0;
float  maxFarDistance     = 0.15;  // in kms
float  maxPacingAngle     = 80.0;  // in degrees
float  maxLappingAngle1   = 220.0; // in degrees
float  maxLappingAngle2   = 270.0; // in degrees

// Filtering
final float  maxAccuracy        = 20;
final float  minSpeed           = 0.5;   // in m/sec
final float  maxSpeed           = 36.11; // in m/sec (130km/h)
final float  maxSpeedWalking    = 1.5;   // in m/sec
final float  minDistance        = 10;    // in m
final float  maxElevationDelta  = 5000;  // in m
final float  maxAcceleration    = 3.0;   // in m/sec2
final float  maxSignalTime      = 60.0;  // in sec

// Map parameters
final int    maxDelay           = 500;   // in ms
final int    maxZoom            = 15;    // in levels
final float  maxPanningDistance = 30;    // in km

String FILE_ROUTE = null;

final String APP_TITLE       = "[FrailSafe] [Orientation Index] [App]";
final String APP_ICON        = "input/icon.png";
final String FILE_PARAMETERS = "input/parameters.txt";

final SimpleDateFormat   dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'hh:mm:ss'Z'");
final SimpleDateFormat msdateFormat = new SimpleDateFormat("yyyy-MM-dd'T'hh:mm:ss.SSS'Z'");

enum TRANSPORTATION_MODE {PEDESTRIAN, VEHICLE}

enum GUI_MODE     {FENCE_POLYGON, GOAL_POINTS}
     GUI_MODE     map_gui    = GUI_MODE.FENCE_POLYGON;

class Fence
{
    static final float m_rect_size       = 10;

    float          m_index;
    float          m_area;
    color          m_color;
    String         m_text;
    boolean        m_connected;
    boolean        m_changed;
    List<Location> m_locations;
    List<Float>    m_radius;
    
    Fence (String text, color col, boolean con)
    {
        m_index     = 0;
        m_color     = col;
        m_text      = text;
        m_connected = con;
        m_changed   = true;
        m_locations = new ArrayList<Location>();
        m_radius    = new ArrayList<Float>();
        load();
    }
    
    boolean  isEmpty ()                      { return m_locations.isEmpty(); }
    
    void     add     (Location loc)          {        m_locations.add(loc);  }
    
    void     remove  (Location loc)          {        m_locations.remove(loc);}

    void     find    (int x, int y)
    {
        Location hit = getFirstHit(x, y);
        if (hit != null)
        {
            if(!m_connected)
              m_radius.remove(m_locations.indexOf(hit));
            m_locations.remove(hit);
        }
        else
        {
            if(!m_connected)
              m_radius.add(maxFarDistance);
            m_locations.add(new Location(myMap.getLocation(x, y)));
        }
        
        save();
        
        m_changed = true;
        
        if(m_locations.size()>2)
            m_area = GeoUtils.getArea(m_locations)*1000;
    }
    
    void     load()
    {
        String[] pieces = split(FILE_ROUTE, ".");     
        File file = new File(dataPath("") + "/output/" + pieces[0] + "_" + m_text + ".txt");
        if (!file.exists())
            return;
   
        BufferedReader input = createReader(dataPath("") + "/output/" + pieces[0] + "_" + m_text + ".txt");
        try
        {
            String line;
            
            while ((line = input.readLine()) != null)
            {
                String[] pieces_in = split(line, ",");
                
                float x = float(pieces_in[0]);
                float y = float(pieces_in[1]);
                
                m_locations.add(new Location(x, y));

                if(!m_connected)
                {
                  if(pieces_in.length == 3)
                      m_radius.add(float(pieces_in[2]));
                  else
                      m_radius.add(maxFarDistance);
                }
            }           
            if(m_locations.size()>2)
                m_area = GeoUtils.getArea(m_locations)*1000;
        }
        catch (IOException e)
        {
            e.printStackTrace();
        }
        finally
        {
            try
            {
              input.close();
              println("Boundary: '" + pieces[0] + "_" + m_text + ".txt" + "' Loaded!");
            }
            catch (IOException e)
            {
                e.printStackTrace();
            }
        }
   }

    void     save()
    {           
         String[] pieces = split(FILE_ROUTE, ".");
         PrintWriter output = createWriter(dataPath("") + "/output/" + pieces[0] + "_" + m_text + ".txt"); 
        
         String radius = "";
         for(int i=0; i < m_locations.size(); i++)
         {
             if(!m_connected)
               radius = "," + m_radius.get(i).toString();
             output.println(m_locations.get(i).getLat() + "," + m_locations.get(i).getLon() + radius);
         }
         
         output.flush();
         output.close();
         println("Boundary: '" + pieces[0] + "_" + m_text + ".txt" + "' Saved!");
    }    
    
    void     drawSphere ()
    {
       fill  (255, 0, 0, 15); // has transparency
       strokeWeight(2);
       for(int i=0; i < m_locations.size(); i++)
       {
           ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));
           
           ScreenPosition Pos2 = myMap.getScreenPosition(GeoUtils.getDestinationLocation(m_locations.get(i),0,m_radius.get(i)));
                     
           int size = (int)Pos2.dist(Pos)*2;

           stroke(0);
           ellipse(Pos.x, Pos.y, size, size);
       }
    }
    
    void     drawPolygon ()
    {
        if(m_locations.size()<3)
            return;
      
       ScreenPosition Pos = new ScreenPosition(0,0);
     
       stroke(0, 0, 0);
       strokeWeight(2);
       fill  (0, 0, 255, 25); // has transparency
       beginShape();
       {
           for(int i=0; i < m_locations.size(); i++)
           {
               Pos = myMap.getScreenPosition(m_locations.get(i));
               vertex(Pos.x, Pos.y);
           }
       }
       endShape();
       
       ScreenPosition pos0 = myMap.getScreenPosition(m_locations.get(0));
       line(pos0.x, pos0.y, Pos.x, Pos.y);
    }

    void     drawPoints ()
    {
        int s   = 14;
        int r_2 = (int) m_rect_size/2;
        
        for(int i=0; i < m_locations.size(); i++ )
        {
            ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i)); 
            strokeWeight(2);
            stroke(m_color);
            strokeCap(SQUARE);
            noFill();
            rect(Pos.x - r_2, Pos.y - r_2, m_rect_size, m_rect_size);
            fill(0);
            text(String.valueOf(m_text.charAt(0)) + i, Pos.x - textWidth(m_text + i) / 2 + s, Pos.y - s);
        }
    }
    
    Location  getFirstHit (int x, int y)
    {
        int r_2 = (int) m_rect_size/2;
        
        for(int i=0; i < m_locations.size(); i++ )
        {
            ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));
            if( x > Pos.x - r_2 && x < Pos.x + r_2 &&
                y > Pos.y - r_2 && y < Pos.y + r_2)
              return m_locations.get(i);
        }
        return null;
    }
    
    boolean   contains (Location loc)
    {
        boolean result = false;       
        for (int i = 0, j = m_locations.size() - 1; i < m_locations.size(); j = i++)
        {
            Location LocI = m_locations.get(i);
            Location LocJ = m_locations.get(j);
            
            if ((LocI.getLon()  > loc.getLon() ) != (LocJ.getLon()  > loc.getLon()) &&
                (loc.getLat()  < (LocJ.getLat()  - LocI.getLat() ) * (loc.getLon()  - LocI.getLon() ) / (LocJ.getLon() - LocI.getLon() ) + LocI.getLat() ))
                result = !result;
        }
        return result;
    }

    public int close  (Location loc)
    {
        for (int i = 0; i < m_locations.size(); i++)
            if (m_locations.get(i).getDistance(loc) < m_radius.get(i))
                return i;
        return -1;
    }
    
    public void draw()
    {
        if(m_connected)
            drawPolygon();
        else
            drawSphere();
        drawPoints();
    }
}

class Route
{
    static final float m_point_size = 15.0;
       
    int            m_sample;
    boolean        m_pause;
    boolean        m_toBeSaved; 
    boolean        m_animation; 
    boolean        m_changed;
    boolean        m_statistics;

    float          m_heatmap_min;
    float          m_heatmap_max;
    float          m_heatmap_diff;
    float          m_index_pacing;
    float          m_index_lapping;
    int            m_pacing_iteration;

    long           m_anim_time;
    long           m_total_time;
    
    int            m_anim_step;
    int            m_total_steps;
       
    float          m_anim_distance;
    float          m_total_distance;   
    
    int            m_total_samples;
    int            m_invalid_samples;
    int            m_duplicate_samples;
    
    Location       m_median;
    List<Location> m_locations;    
    List<Float>    m_times;     // in seconds
    List<Float>    m_speeds;    // in m/s
    List<Float>    m_angles;    // in degrees
    List<Float>    m_distances; // in meters
    List<Float>    m_accelerations; // in m/s^2
    List<Float>    m_grades;
    
    List<Long>     m_dates;
    List<Float>    m_steps;
    List<Float>    m_accuracy;
    List<Float>    m_bearings;
    List<Float>    m_elevations;
   
    int            m_step = 1;
    long           m_step_time = 60000; //1 min
    
    List<Boolean>  m_indoor;
    List<Boolean>  m_invalid;
    List<Boolean>  m_duplicate;
    List<Boolean>  m_signal_lost;
    List<TRANSPORTATION_MODE> m_transportation;
    
    List<Boolean>  m_IsInside;
    List<Integer>  m_IsClose;
    List<Float>    m_heatmap_values;
    String         m_heatmap_string;
       
    Route (PApplet p)
    {
        m_pause            = false;
        m_changed          = true;
        m_animation        = false;   
        m_statistics       = true;
        m_toBeSaved        = false;

        m_sample           = 0;
        m_index_pacing     = 0;
        m_index_lapping    = 0;
        m_pacing_iteration = 0;
        
        m_invalid_samples  = 0;
        m_duplicate_samples= 0;
        
        loadParameters();
        loadRoute(p);
        
        preprocessing();
        computeHeatmap("Elevation", m_elevations);
    }
    
    void     saveIndex()
    {      
         if(!m_toBeSaved || m_animation)
             return;
          
         String[] pieces = split(FILE_ROUTE, ".");
         PrintWriter output = createWriter(dataPath("") + "/output/" + pieces[0] + "_Index.txt"); 
        
         output.println( myFence.m_index + " // Polygon Fence\n"      +
                         myGoals.m_index + " // Points of Interest\n" +
                         m_index_pacing  + " // Pacing\n"             +
                         m_index_lapping + " // Lapping"  );
        
         output.flush();
         output.close();
         println("Orientation Indices: '" + pieces[0] + "_Index.txt' Saved!");
         
         m_toBeSaved = false;
    } 
     
    public double angleBetweenTwoPointsWithFixedPoint(double x1, double y1, double x2, double y2, double x, double y)
    {
        double ax =x1-x;
        double ay =y1-y;

        double bx =x2-x;
        double by =y2-y;
        
        double angle = Math.atan2(ax*by - ay*bx, ax*bx + ay*by);
                 
        return (ax*by - ay*bx < 0) ? -angle : angle;
    }
        
    private void loadParameters()
    { 
        BufferedReader input = createReader(FILE_PARAMETERS);
        try
        {
            String line;
            String[] pieces;
            {
                line   = input.readLine();          
                pieces = split(line, "//");
                maxFarDistance = float(pieces[0]);
            }          
            {
                line   = input.readLine();
                pieces = split(line, "//");
                maxPacingAngle = float(pieces[0]);
            }
            {
                line   = input.readLine();
                pieces = split(line, "//");
                maxLappingAngle1 = float(pieces[0]);
            }
            {
                line   = input.readLine();
                pieces = split(line, "//");
                maxLappingAngle2 = float(pieces[0]);
            }
        }
        catch (IOException e)
        {
            e.printStackTrace();
        }
        finally
        {
            try
            {
              input.close();
              println("Parameters: '" + FILE_PARAMETERS + "' Loaded!");
            }
            catch (IOException e)
            {
                e.printStackTrace();
            }
        }      
    }
    
    private boolean invalidAccuracy(float acc)
    {
        return (acc > maxAccuracy) ? true : false; 
    }

    private boolean invalidSpeed(float spe)
    {
        return (spe > maxSpeed) ? true : false;
    }    

    private boolean invalidDistance(int k, int k_prev, int k_next)
    {
        return (GeoUtils.getDistance(m_locations.get(k),m_locations.get(k_prev))*1000.0 < minDistance || GeoUtils.getDistance(m_locations.get(k_prev), m_locations.get(k_next))*1000.0 < minDistance) ? true : false;
    }
    
    private boolean invalidAcceleration(float acc)
    {
        return (acc > maxAcceleration || acc < -maxElevationDelta) ? true : false; 
    }
    
    private boolean invalidElevation(float ele)
    {
        return (Math.abs(ele) > maxElevationDelta) ? true : false;
    }
    
    private boolean isSignalLost(float time)
    {
        return (time > maxSignalTime) ? true : false;
    }
    
    private void loadRoute(PApplet p)
    {
        m_dates      = new ArrayList<Long>();       
        m_times      = new ArrayList<Float>();
        m_speeds     = new ArrayList<Float>();
        m_angles     = new ArrayList<Float>();
        m_grades     = new ArrayList<Float>();
        m_distances  = new ArrayList<Float>();
        m_elevations = new ArrayList<Float>();
        m_steps      = new ArrayList<Float>();
        m_accuracy   = new ArrayList<Float>();
        m_bearings   = new ArrayList<Float>();
        m_indoor     = new ArrayList<Boolean>();
        m_IsInside   = new ArrayList<Boolean>();
        m_IsClose    = new ArrayList<Integer>();
        m_locations  = new ArrayList<Location>();        
        m_accelerations = new ArrayList<Float>();
        
        m_transportation = new ArrayList<TRANSPORTATION_MODE>();
        
        m_invalid     = new ArrayList<Boolean>();
        m_duplicate   = new ArrayList<Boolean>();
        m_signal_lost = new ArrayList<Boolean>();
        
        if(split(FILE_ROUTE, ".")[1].equals("txt"))
        {
            // Init route (TXT)
            String[] route_data = loadStrings(FILE_ROUTE);
            for(int i=1; i<route_data.length; i++)
            {
                String[] thisRow = split(route_data[i], ",");
                Date date;
                try
                {
                    if       (thisRow[0].length() == 20)
                        date = dateFormat.parse(thisRow[0]);
                    else if  (thisRow[0].length() == 24)
                        date = msdateFormat.parse(thisRow[0]);
                    else
                        date = new Date(Long.parseLong(thisRow[0])); // try for unix time
                }
                catch(Exception e)
                {
                        date = new Date();
                }
                
                // loading
                long     time  = date.getTime();
                Location loc   = new Location(float(thisRow[1]), float(thisRow[2]));
                float    elev  = float(thisRow[3]);
                float    accur = float(thisRow[4]);
                float    bear  = float(thisRow[5]);
                float    steps = (thisRow.length == 7) ? 0.0f : float(thisRow[7]);

                m_dates.add(time);
                m_steps.add(steps);
                m_locations.add(loc);
                m_bearings.add(bear);
                m_accuracy.add(accur);
                m_elevations.add(elev);
                
                m_IsInside.add(false);
                m_IsClose.add (-1);       
                
                m_total_samples++;                
            }
        }
        else
        {
          // Init route (GPX)
          GPX gpx = new GPX(p);
          gpx.parse(FILE_ROUTE); 
          for (int i = 0; i < gpx.getTrackCount(); i++)
          {
              GPXTrack trk = gpx.getTrack(i); // do something with 
             
              for (int j = 0; j < trk.size(); j++)
              {
                  GPXTrackSeg trkseg = trk.getTrackSeg(j);
                  for (int k = 0; k < trkseg.size(); k++)
                  {
                      GPXPoint pt = trkseg.getPoint(k);
                      
                      // loading
                      long     time  = pt.time.getTime();
                      Location loc   = new Location(pt.lat, pt.lon);
                      float    elev  = (float)pt.ele;
                      float    steps = 0.0f;
                      float    accur = 0.0f;
                      float    bear  = 0.0f;
                                                                
                      m_dates.add(time);
                      m_steps.add(steps);
                      m_locations.add(loc);
                      m_bearings.add(bear);
                      m_accuracy.add(accur);
                      m_elevations.add(elev);
                      
                      m_IsInside.add(false);
                      m_IsClose.add (-1);
                      
                      m_total_samples++;
                  }
              }
          }
        }
        println("Track Name: '" + FILE_ROUTE + "' Loaded!");
     }
      
    private void preprocessing()
    {       
       m_median = GeoUtils.getEuclideanCentroid(m_locations);
       
       m_times.add(0.0);
       m_grades.add(0.0);
       m_speeds.add(0.0);
       m_distances.add(0.0);
       m_accelerations.add(0.0);

       m_transportation.add(TRANSPORTATION_MODE.PEDESTRIAN);

       m_invalid.add(false);
       m_signal_lost.add(false);
       
       m_total_time     = 0;
       m_total_steps    = 0;
       m_total_distance = 0.0;    
       
       int k_prev = 0;
       for(int k=1; k < m_locations.size(); k++)
       {
          float time         = (m_dates.get(k) - m_dates.get(k_prev))/1000.0;                                     // convert to seconds
          float distance     = (float) GeoUtils.getDistance(m_locations.get(k),m_locations.get(k_prev))* 1000.0;  // convert to meters                           
          float speed        = distance/time;
          float acceleration = (speed - m_speeds.get(k_prev))/time;
          float elev_delta   = m_elevations.get(k) - m_elevations.get(k_prev);
          float grade        = elev_delta/distance;

          // 1. SIGNAL LOST
          m_signal_lost.add(isSignalLost((m_dates.get(k) - m_dates.get(k-1))/1000.0));

          // 2. INVALID
          if(  invalidAccuracy      (m_accuracy.get(k))      ||
               invalidSpeed         (speed)                  ||
               invalidElevation     (elev_delta)             ||
               invalidAcceleration  (acceleration)  
            )
          {
              m_invalid_samples++;
              m_invalid.add(true);
          }
          else
          {
              k_prev = k;
              m_invalid.add(false);
          }

          m_times.add         (time);
          m_speeds.add        (speed);
          m_distances.add     (distance);          
          m_accelerations.add (acceleration);
          m_grades.add        (grade);
          
          if(speed < maxSpeedWalking)
              m_transportation.add(TRANSPORTATION_MODE.PEDESTRIAN);
          else
              m_transportation.add(TRANSPORTATION_MODE.VEHICLE);
          
          if(!m_invalid.get(k))
          {
              m_total_steps     += m_steps.get(k);
              m_total_distance  += distance;
              m_total_time      += time;          
          }
       }
       m_invalid.add(false);
       m_signal_lost.add(false);

       m_angles.add(0.0);
       m_duplicate.add(false);
       
       k_prev = 0;
       for(int k=1; k < m_locations.size()-1; k++)
       {   
           if(m_invalid.get(k))
           {
               m_angles.add(0.0);
               m_duplicate.add(false);
               continue;
           }
           
           // Compute NEXT
           int k_next = k+1;
           while(m_invalid.get(k_next))
                k_next++;

            // Compute DUPLICATE
           if(invalidDistance(k, k_prev, k_next))
           {
               m_angles.add(0.0);
               m_duplicate.add(true);
               m_duplicate_samples++;
               continue;
           }
           else
               m_duplicate.add(false);           

           // Compute ANGLE
           double a = angleBetweenTwoPointsWithFixedPoint(
                        m_locations.get(k_prev).x,
                        m_locations.get(k_prev).y,
                        m_locations.get(k_next).x,
                        m_locations.get(k_next).y,
                        m_locations.get(k     ).x,
                        m_locations.get(k     ).y);
           m_angles.add((float)Math.abs(Math.toDegrees(a)));
           
           // Compute PREV
           k_prev = k;
       }
       m_duplicate.add(false);
       m_angles.add(0.0);
    }

    private void computeHeatmap(String s, List<Float> list)
    {      
        m_heatmap_string = s;
      
        m_heatmap_values = new ArrayList<Float>(list.size());
        m_heatmap_min    =  Float.MAX_VALUE;
        m_heatmap_max    = -Float.MAX_VALUE;       
               
        for(int i=1; i < list.size(); i++)
        {
            float v = list.get(i);
            if(v < m_heatmap_min) m_heatmap_min = v;
            if(v > m_heatmap_max) m_heatmap_max = v;
        }
        
        m_heatmap_diff = m_heatmap_max - m_heatmap_min;
        for(int i=0; i < list.size(); i++)
            m_heatmap_values.add(i,(list.get(i)-m_heatmap_min)/m_heatmap_diff);
    }
  
    private void drawMarker(int i, color col, String text, PImage img)
    {
        ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));
        
        if(text != "")
        {     
            fill(0);
            text(text, Pos.x - textWidth(text) / 2, Pos.y + 34);
        }
    
        stroke(col);
        strokeWeight(2);
        strokeCap(ROUND);
        noFill();
        
        arc(Pos.x, Pos.y, m_point_size, m_point_size, -PI * 0.9, -PI * 0.1);
        arc(Pos.x, Pos.y, m_point_size, m_point_size,  PI * 0.1,  PI * 0.9);
       
        imageMode(CENTER);
        image(img, Pos.x, Pos.y - img.height/2);
        imageMode(CORNER);
    }
  
    private void drawSamplePoints(int size)
    {       
        noFill();
        for(int i=0; i < m_locations.size(); i++)
        {
            ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));

            if     (m_invalid.get(i))
            {
                if(m_statistics)
                    stroke(255, 0, 0); // Red
                else
                    continue;
            }             
            else if(m_duplicate.get(i))
            {
                if(m_statistics)
                    stroke(255, 0, 255); // Magenta
                else
                    continue;
            }
            else if(m_signal_lost.get(i))
            {
                if(m_statistics)
                    stroke(255, 255, 0); // Yellow
                else
                    continue;
            }            
            else
                stroke(0, 0, 0);
            ellipse(Pos.x, Pos.y, size, size);
        }
    }
/*
    private void drawSampleLines(Fence fence, int size)
    {
        if(fence.isEmpty())
            return;
     
        noFill();
        strokeWeight(1);
        for(int i=0; i < m_locations.size(); i++)
        {
           // ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));
            int id = m_IsClose.get(i);
            
            if(id > -1)
            {
                stroke(255,128,0);
//                line(Pos.x-size,Pos.y+size,Pos.x+size,Pos.y-size);
  //              line(Pos.x-size,Pos.y-size,Pos.x+size,Pos.y+size);
            
               // ScreenPosition Goal = myMap.getScreenPosition(fence.m_locations.get(id));
                //strokeWeight(1);
                //stroke(0,0,0,50);
                //line(Pos.x, Pos.y, Goal.x, Goal.y);
            }
        }
    }*/
  
    private void computeFenceIndex(Fence fence)
    {           
        if(fence.isEmpty() || (!fence.m_changed && !m_animation))
        {
            m_toBeSaved |= false;
            return;
        }
        
        fence.m_changed = false;
        fence.m_index = 0;
        
        int total_samples = 0;
        for(int i=0; i < m_locations.size(); i++)
        {
            if(m_invalid.get(i) || m_duplicate.get(i) || m_signal_lost.get(i))
                continue;
          
            if(fence.contains(m_locations.get(i)))
            {
                m_IsInside.add(i, true);
                if(!m_animation || i <= m_sample)
                    fence.m_index++;
            }          
            else
                m_IsInside.add(i, false);
            
            if(!m_animation || i <= m_sample)
                total_samples++;
        }
        
        if(total_samples > 0)
            fence.m_index /= (float) total_samples;
            
        m_toBeSaved |= true;
    }
    
    private void computeGoalIndex(Fence fence)
    {           
        if(fence.isEmpty() || (!fence.m_changed && !m_animation))
        {
            m_toBeSaved |= false;
            return;
        }
        
        fence.m_changed = false;
        fence.m_index = 0;

        int id            = -1;
        int total_samples = 0;
        for(int i=0; i < m_locations.size(); i++)
        {
            if(m_invalid.get(i) || m_duplicate.get(i) || m_signal_lost.get(i))
                continue;
                
            if((id = fence.close(m_locations.get(i))) > -1)
            {       
                if(!m_animation || i <= m_sample)
                    fence.m_index++;
            }          
            m_IsClose.add(i, id);
            
            if(!m_animation || i <= m_sample)
                total_samples++;
        }
        
        if(total_samples > 0)
            fence.m_index /= (float) total_samples;
            
        m_toBeSaved |= true;
    }
    
    private void computePacingIndex()
    {                  
        if(!m_changed && !m_animation)
        {
            m_toBeSaved |= false;
            return;
        }
        
        m_index_pacing     = 0;
        m_pacing_iteration = 1;
        
        int total_samples = 0;
        for(int i=1; i < m_locations.size()-1; i++)
        {   
            if(m_invalid.get(i) || m_duplicate.get(i) || m_signal_lost.get(i))
                continue;          
          
            if(!m_animation || i <= m_sample)
            {
                if(m_angles.get(i) > maxPacingAngle)
                {
                    m_index_pacing++;
                    m_pacing_iteration = 1;
                }
                else
                {
                    m_index_pacing     += (m_pacing_iteration>=10) ? 0.0f : 1.0 - 1.0/(float)Math.pow(2,m_pacing_iteration);
                    m_pacing_iteration ++;
                }
                total_samples++;
            }
            
        }
        
        if(total_samples > 0)
            m_index_pacing /= (float) total_samples;
            
        m_toBeSaved |= true;
    }
    
    private void computeLappingIndex()
    {                  
        if(!m_changed && !m_animation)
        {
            m_toBeSaved |= false;
            return;
        }

        m_changed = false;
        m_index_lapping    = 0;
               
        int total_samples = 0;
        for(int i=0; i < m_locations.size(); i++)
        {
            if(m_invalid.get(i) || m_duplicate.get(i) || m_signal_lost.get(i))
                continue;          
          
            int   a_k    = 0;
            float a_prev = 0;
            float a_sum  = 0;
            float a_curr, a_diff;
          
            if(!m_animation || i <= m_sample)
            {
                for(int k=0, j= i+1; j < m_locations.size() && k < 10; j++, k++)             
                {
                    if(m_invalid.get(j) || m_duplicate.get(j) || m_signal_lost.get(j))
                        continue;      
                  
                    a_curr = (float) Math.toDegrees(GeoUtils.getAngleBetween(m_locations.get(i),m_locations.get(j)));
                    
//println("-" + j + ": " + a_curr);
                    if(k>0)
                    {                     
                        a_diff = a_curr-a_prev;
                        
//println("*" + j + ": " + a_diff);
                        if     (a_diff < -180) a_diff = 360 + a_diff;
                        else if(a_diff >  180) a_diff = 360 - a_diff;
                        
                       if(Math.abs(a_sum) > Math.abs(a_sum+a_diff))
                           break;
                       
                       a_sum += a_diff;
                       a_k++;
                       
 //println(i + "*" + k + ": " + a_sum);
                        //if(Math.abs(a_sum) > 300)
                          //  println(i + "*" + k + ": " + a_sum);
                            //break;
                    }
                    a_prev = a_curr;
                }
                
               a_k *= 2; 
               if     (Math.abs(a_sum) < maxLappingAngle1)
                   m_index_lapping++;
               else if(Math.abs(a_sum) < maxLappingAngle2)
                   m_index_lapping += 1.0/a_k;
               else
                   m_index_lapping += 1.0/(a_k*2);
               
               total_samples++;
             }
        }
        
        if(total_samples > 0)
            m_index_lapping /= (float) total_samples;
            
        m_toBeSaved |= true;
    }
     
    private void drawRoute()
    {  
       //colorMode(HSB, 2);
       
       stroke(0);
       strokeWeight(4);
       noFill();
       beginShape();
       for(int i=0; i < m_locations.size(); i++)
       {
           if(m_invalid.get(i) || m_duplicate.get(i))
               continue;
         
           ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));
           vertex(Pos.x, Pos.y);
       }
       endShape();

       stroke(255,255,255);
       strokeWeight(2);
       beginShape();
       for(int i=0; i < m_locations.size(); i++)
       {
           if(m_invalid.get(i) || m_duplicate.get(i))
               continue;
         
          //stroke(m_heatmap_values.get(i), 2, 2);
          
          ScreenPosition Pos = myMap.getScreenPosition(m_locations.get(i));
          vertex(Pos.x, Pos.y);
       }
       endShape();
       
       colorMode(RGB, 255);
    }
  
    private void drawHeatmap()
    {
        float w =  textWidth(m_heatmap_string) + 20;
        stroke(0);
        strokeWeight(2);
        fill(255);
        rect(width - w, 0 , 90, 90);
        line(width - w, 20, width, 20 );
        image(map_bar_heatmap, width - map_bar_heatmap.width*1.5, 35);
        fill(0);
        text(m_heatmap_string, width - w+10, 15);
        text(String.format("%.3f", m_heatmap_min), width - w  + 5 , 45);
        text(String.format("%.3f", m_heatmap_max), width - w  + 5 , 85);
    }
    
    private void drawIndexValues()
    {
        int p = 15;
        int l = 40;
        int y = 220;
        int z = 340;
      
        stroke(0);
        strokeWeight(2);
        fill(255);
        rect(0, 0 , y, z);
        fill(0);
        text("Route:           '" + FILE_ROUTE + "'", 5, p); // Name
        p+=20;
        text("Inv/Dupl/Tot:  "    + m_invalid_samples + "/" + m_duplicate_samples + "/" + (m_invalid_samples+m_duplicate_samples), 5, p); // Filtering
        p+=20;       
        fill(255);
        line(0, l , y, l );
        l += 120;
        fill(0);
        text("Sample (Acc):  "     + m_sample           + " (" + String.format("%.0f", m_accuracy.get(m_sample)) + ")/" + (m_total_samples-1), 5, p); // Sample
        p+=20;  
        text("Time:             "  + String.format("%.0f", m_times.get(m_sample))    + "/" + m_anim_time         + "/" + m_total_time+ "s", 5, p) ;   // Time 
        p+=20;      
        text("Distance:        "   + String.format("%.0f", m_distances.get(m_sample))+ "/" + String.format("%.0f", m_anim_distance) + "/" + String.format("%.0f", m_total_distance) + "m", 5, p); // Distance 
        p+=20;
        text("Speed (Accel): "     + String.format("%.2f", m_speeds.get(m_sample))   + "m/s (" + String.format("%.2f", m_accelerations.get(m_sample))+ ")", 5, p);       // Speed 
        p+=20;
        text("Elevet (Grade): "    + String.format("%.0f", m_elevations.get(m_sample)) + "m (" + String.format("%.2f", m_grades.get(m_sample))+ "%)", 5, p);       // Speed 
        p+=20;        
        text("Steps:             " + String.format("%.0f", m_steps.get(m_sample))    + "/" + m_anim_step         + "/" + m_total_steps, 5, p);       // Steps 
        p+=20;        
        text("Transportation: " + ((m_transportation.get(m_sample) == TRANSPORTATION_MODE.PEDESTRIAN) ? "PEDESTRIAN" : "VEHICLE"), 5, p);   // Transformation Index
        p+=20;
        fill(255);
        line(0, l , y, l );
        l += 20;
        fill(0);
        text("Fence Polygon Index:"          , 5, p);   // Fence
        p+=20;
        fill(255);
        line(0, l , y, l );
        l += 40;
        fill(0);
        text(String.format("%.3f", myFence.m_index)                                              , 5, p);
        p+=20;
        text("Point of Interest Index:"           , 5, p);   // Point of Interest Locations
        p+=20;
        fill(255);
        line(0, l , y, l );
        l += 40;
        fill(0);        
        text(String.format("%.3f", myGoals.m_index)         + " (" + maxFarDistance   + "km)"    , 5, p);
        p+=20;
        text("Pacing Index:"         , 5, p);  // Pacing
        p+=20;
        fill(255);
        line(0, l , y, l );
        l += 40;
        fill(0);         
        text(String.format("%.3f", myRoute.m_index_pacing)  + " (" + maxPacingAngle   + "\u00b0)", 5, p);
        p+=20;
        text("Lapping Index:"        , 5, p);  // Lapping
        p+=20;
        fill(255);
        line(0, l , y, l );
        l += 40;
        fill(0);        
        text(String.format("%.3f", myRoute.m_index_lapping) + " (" + maxLappingAngle1 + "\u00b0, " + maxLappingAngle2 + "\u00b0)", 5, p);
        p+=20;
    }
     
    public void draw()
    {        
        drawRoute          ();
        
        drawMarker         (0                     , color(0,0,0  ), "START", map_pin_green);
        drawMarker         (m_locations.size() - 1, color(0,0,0  ), "END"  , map_pin_red);  
        drawMarker         (m_sample              , color(0,0,255), ""     , map_pin_old); 
        drawSamplePoints   (3);
        
        computePacingIndex ();
        computeLappingIndex();
        computeFenceIndex  (myFence);
        computeGoalIndex   (myGoals);
        saveIndex          ();
              
//        if(m_statistics)
            drawIndexValues();
        
        animate();
    }
    
    private void animate()
    {
        if(m_animation && !m_pause)
        {
            delay(maxDelay);
            
            int k = m_step;
            while(m_sample+k < m_locations.size() && (m_invalid.get(m_sample+k) || m_duplicate.get(m_sample+k)))
                k++;
              
            m_sample        += k;             
            if(m_sample >= m_locations.size())
            {
                m_sample    = m_locations.size()-1;
                m_animation = false;
            }
            else
            {
                m_anim_distance += m_distances.get(m_sample);
                m_anim_time     += m_times.get(m_sample);
                m_anim_step     += m_steps.get(m_sample);
            }
        }
    }    
} 

void fileSelected(File selection)
{
    if (selection == null)
    {
        println("Window was closed or the user hit cancel.");
        exit();
    }
    else
    {
        FILE_ROUTE = selection.getName();   
    }
}

void setup()
{ 
    noLoop();
    selectInput("Select a ROUTE file to process:", "fileSelected");
    
    while (FILE_ROUTE == null)
       delay(2000);
    loop();
    
    // 1. Load Route
    myRoute = new Route(this);
          
    // 1. Init Providers
    myProviders = new ArrayList<AbstractMapProvider>();
    myProviders.add(new GeoMapApp.TopologicalGeoMapProvider());  
    myProviders.add(new OpenStreetMap.OpenStreetMapProvider());
    //myProviders.add(new Google.GoogleMapProvider());
    //myProviders.add(new Google.GoogleTerrainProvider());    
    myProviders.add(new Microsoft.AerialProvider());
    myProviders.add(new Microsoft.HybridProvider());
    myProviders.add(new Microsoft.RoadProvider());
    //myProviders.add(new StamenMapProvider.TonerBackground());
    //myProviders.add(new StamenMapProvider.TonerLite());
    //myProviders.add(new StamenMapProvider.WaterColor());
    //myProviders.add(new EsriProvider.WorldGrayCanvas());
    //myProviders.add(new EsriProvider.WorldStreetMap());
    //myProviders.add(new EsriProvider.WorldTopoMap());

    myMap = new UnfoldingMap    (this, myProviders.get(0));     
    myMap.zoomAndPanTo          (maxZoom, myRoute.m_median);
    myMap.setPanningRestriction (myRoute.m_median, maxPanningDistance);
    myMap.setTweening           (true);
    MapUtils.createDefaultEventDispatcher(this, myMap);
    
    // 3. Load Route
    myFence = new Fence("Fence", color(0  ,0  ,255), true);
    myGoals = new Fence("PoI"  , color(255,128,0  ), false);
    
    // 4. Init Figs
    map_pin_red       = loadImage("input/pin_red.png");
    map_pin_green     = loadImage("input/pin_green.png");
    map_pin_old       = loadImage("input/pin_old.png");  
    map_bar_heatmap   = loadImage("input/heatmap_bar.png");
    
    surface.setTitle(APP_TITLE);
}

void settings()
{
    size(1280, 768, P3D);
    smooth();
    
    PJOGL.setIcon(APP_ICON);
}
 
void draw()
{
    this.clear();
    myMap.draw(); 
    myRoute.draw();
    myFence.draw();
    myGoals.draw();
}

void mousePressed()
{   
    if (mouseButton == RIGHT)
    {
        if(map_gui == GUI_MODE.FENCE_POLYGON)
            myFence.find(mouseX, mouseY);
        else
            myGoals.find(mouseX, mouseY);        
    } 
}

void keyPressed()
{
   if       (key == 'a')
   {
       myRoute.m_animation     = !myRoute.m_animation;
       myRoute.m_sample        = 0;
       myRoute.m_anim_step     = 0;
       myRoute.m_anim_distance = 0.0;
       myRoute.m_anim_time     = 0;
       
       myFence.m_changed = true;
       myGoals.m_changed = true;
   }
   else if (key == 'c')
   {
       myFence.m_locations.clear(); myFence.m_index = 0.0;
       myGoals.m_locations.clear(); myGoals.m_index = 0.0;
       myFence.save();
       myGoals.save();
       
       myRoute.m_IsInside = new ArrayList<Boolean>();
       myRoute.m_IsClose  = new ArrayList<Integer>();
       for(int i=0; i < myRoute.m_locations.size(); i++)
       {
           myRoute.m_IsInside.add(false);
           myRoute.m_IsClose.add (-1);
       }  
       
       myRoute.m_index_pacing  = 0.0;
       myRoute.m_index_lapping = 0.0;
       myRoute.m_changed = true;
   }  
   else if (key == 'p')
        myRoute.m_pause = !myRoute.m_pause;
   else if (key == 'h')
        myRoute.m_statistics = !myRoute.m_statistics;       
   else if (keyCode == 9) // Tab
   {
       if(map_gui == GUI_MODE.FENCE_POLYGON)
         map_gui = GUI_MODE.GOAL_POINTS;
       else
         map_gui = GUI_MODE.FENCE_POLYGON;
   }
   else if (keyCode == 11) // PgUp
   {    
       curr_provider++;
       if(curr_provider == myProviders.size())
         curr_provider = 0;
       myMap.mapDisplay.setProvider(myProviders.get(curr_provider));
   }
   else if (keyCode == 16) // PgDn
   {
       curr_provider--;
       if(curr_provider < 0 )
         curr_provider = myProviders.size()-1;
       myMap.mapDisplay.setProvider(myProviders.get(curr_provider));
   }
   
  // println("key: "     + key);
  // println("keyCode: " + keyCode); 
}