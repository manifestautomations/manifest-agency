export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          username: string | null
          avatar_url: string | null
          dietary_preferences: string[] | null -- Parsed JSON
          household_size: number | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          username?: string | null
          avatar_url?: string | null
          dietary_preferences?: string[] | null
          household_size?: number | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          username?: string | null
          avatar_url?: string | null
          dietary_preferences?: string[] | null
          household_size?: number | null
          created_at?: string
          updated_at?: string
        }
      }
      items: {
        Row: {
          barcode: string
          name: string
          brand: string | null
          category: string | null
          default_unit: string | null
          image_url: string | null
          created_at: string
        }
        Insert: {
          barcode: string
          name: string
          brand?: string | null
          category?: string | null
          default_unit?: string | null
          image_url?: string | null
          created_at?: string
        }
        Update: {
          barcode?: string
          name?: string
          brand?: string | null
          category?: string | null
          default_unit?: string | null
          image_url?: string | null
          created_at?: string
        }
      }
      pantry_items: {
        Row: {
          id: string
          user_id: string
          barcode: string | null
          name: string
          quantity: number
          unit: string | null
          expiry_date: string | null -- Date string
          location: string | null
          is_consumed: boolean
          added_at: string
        }
        Insert: {
          id?: string
          user_id: string
          barcode?: string | null
          name: string
          quantity?: number
          unit?: string | null
          expiry_date?: string | null
          location?: string | null
          is_consumed?: boolean
          added_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          barcode?: string | null
          name?: string
          quantity?: number
          unit?: string | null
          expiry_date?: string | null
          location?: string | null
          is_consumed?: boolean
          added_at?: string
        }
      }
      recipes: {
        Row: {
          id: string
          user_id: string
          title: string
          description: string | null
          instructions: Json[] -- Array of step objects
          ingredients_matched: Json | null
          is_favorite: boolean
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          title: string
          description?: string | null
          instructions: Json[]
          ingredients_matched?: Json | null
          is_favorite?: boolean
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          title?: string
          description?: string | null
          instructions?: Json[]
          ingredients_matched?: Json | null
          is_favorite?: boolean
          created_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}
